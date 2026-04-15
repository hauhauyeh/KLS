using KLS.Contract.Interfaces;
using KLS.Contract.Services.Marketplace.Ebay;
using KLS.Models;
using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;

namespace KLS.Services.Marketplace.Ebay
{
    public class EbayTokenService : BaseService, IEbayTokenService
    {
        private readonly IHttpClientFactory _httpClientFactory;
        private static readonly ConcurrentDictionary<int, SemaphoreSlim> _accountLocks = new();

        private const string ProductionTokenUrl = "https://api.ebay.com/identity/v1/oauth2/token";
        private const string SandboxTokenUrl = "https://api.sandbox.ebay.com/identity/v1/oauth2/token";

        // Scopes required for Inventory/Offer/Fulfillment APIs
        private const string DefaultScopes =
            "https://api.ebay.com/oauth/api_scope " +
            "https://api.ebay.com/oauth/api_scope/sell.inventory " +
            "https://api.ebay.com/oauth/api_scope/sell.account " +
            "https://api.ebay.com/oauth/api_scope/sell.fulfillment";

        public EbayTokenService(IUnitOfWork uow, IHttpClientFactory httpClientFactory) : base(uow)
        {
            _httpClientFactory = httpClientFactory;
        }

        public async Task<string> GetAccessTokenAsync(int marketAccountId)
        {
            var account = Uow.MarketAccounts.GetById(marketAccountId)
                ?? throw new InvalidOperationException("Market account not found");

            var settings = EbaySettings.FromEncrypted(account.SettingsJson);
            if (string.IsNullOrWhiteSpace(settings.ClientId)
                || string.IsNullOrWhiteSpace(settings.ClientSecret)
                || string.IsNullOrWhiteSpace(settings.RefreshToken))
            {
                throw new InvalidOperationException("eBay ClientId/ClientSecret/RefreshToken not configured");
            }

            if (settings.IsTokenValid) return settings.AccessToken!;

            var gate = _accountLocks.GetOrAdd(marketAccountId, _ => new SemaphoreSlim(1, 1));
            await gate.WaitAsync();
            try
            {
                Uow.MarketAccounts.Reload(account);
                settings = EbaySettings.FromEncrypted(account.SettingsJson);
                if (settings.IsTokenValid) return settings.AccessToken!;

                var client = _httpClientFactory.CreateClient("EbayAuth");
                var tokenUrl = settings.IsSandbox ? SandboxTokenUrl : ProductionTokenUrl;
                var request = new HttpRequestMessage(HttpMethod.Post, tokenUrl);
                var basic = Convert.ToBase64String(Encoding.UTF8.GetBytes($"{settings.ClientId}:{settings.ClientSecret}"));
                request.Headers.Authorization = new AuthenticationHeaderValue("Basic", basic);
                request.Content = new FormUrlEncodedContent(new Dictionary<string, string>
                {
                    ["grant_type"] = "refresh_token",
                    ["refresh_token"] = settings.RefreshToken!,
                    ["scope"] = DefaultScopes
                });

                var response = await client.SendAsync(request);
                var body = await response.Content.ReadAsStringAsync();
                if (!response.IsSuccessStatusCode)
                    throw new InvalidOperationException($"eBay token refresh failed ({(int)response.StatusCode}): {body}");

                var tokenResponse = JsonSerializer.Deserialize<EbayTokenResponse>(body)
                    ?? throw new InvalidOperationException("Invalid eBay token response");

                settings.AccessToken = tokenResponse.access_token;
                settings.TokenExpiresAt = DateTime.UtcNow.AddSeconds(tokenResponse.expires_in);
                account.SettingsJson = settings.ToEncrypted();
                account.UpdatedAt = DateTime.UtcNow;
                Uow.MarketAccounts.Update(account);
                Uow.Commit();

                return settings.AccessToken;
            }
            finally
            {
                gate.Release();
            }
        }
    }
}
