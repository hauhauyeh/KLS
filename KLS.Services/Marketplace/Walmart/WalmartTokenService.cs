using KLS.Contract.Interfaces;
using KLS.Contract.Services.Marketplace.Walmart;
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

namespace KLS.Services.Marketplace.Walmart
{
    public class WalmartTokenService : BaseService, IWalmartTokenService
    {
        private readonly IHttpClientFactory _httpClientFactory;
        private static readonly ConcurrentDictionary<int, SemaphoreSlim> _accountLocks = new();
        private const string DefaultTokenUrl = "https://marketplace.walmartapis.com/v3/token";

        public WalmartTokenService(IUnitOfWork uow, IHttpClientFactory httpClientFactory) : base(uow)
        {
            _httpClientFactory = httpClientFactory;
        }

        public async Task<string> GetAccessTokenAsync(int marketAccountId)
        {
            var account = Uow.MarketAccounts.GetById(marketAccountId)
                ?? throw new InvalidOperationException("Market account not found");

            var settings = WalmartSettings.FromEncrypted(account.SettingsJson);
            if (string.IsNullOrWhiteSpace(settings.ClientId) || string.IsNullOrWhiteSpace(settings.ClientSecret))
                throw new InvalidOperationException("Walmart ClientId/ClientSecret not configured");

            if (settings.IsTokenValid)
                return settings.AccessToken!;

            var gate = _accountLocks.GetOrAdd(marketAccountId, _ => new SemaphoreSlim(1, 1));
            await gate.WaitAsync();
            try
            {
                Uow.MarketAccounts.Reload(account);
                settings = WalmartSettings.FromEncrypted(account.SettingsJson);
                if (settings.IsTokenValid)
                    return settings.AccessToken!;

                var client = _httpClientFactory.CreateClient("WalmartAuth");
                var request = new HttpRequestMessage(HttpMethod.Post, GetTokenUrl(account));
                var basic = Convert.ToBase64String(Encoding.UTF8.GetBytes($"{settings.ClientId}:{settings.ClientSecret}"));
                request.Headers.Authorization = new AuthenticationHeaderValue("Basic", basic);
                request.Content = new FormUrlEncodedContent(new Dictionary<string, string>
                {
                    ["grant_type"] = "client_credentials"
                });

                var response = await client.SendAsync(request);
                response.EnsureSuccessStatusCode();

                var json = await response.Content.ReadAsStringAsync();
                var tokenResponse = JsonSerializer.Deserialize<WalmartTokenResponse>(json)
                    ?? throw new InvalidOperationException("Invalid Walmart token response");

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

        private static string GetTokenUrl(MarketAccount account)
        {
            var baseUrl = string.IsNullOrWhiteSpace(account.ApiBaseUrl)
                ? "https://marketplace.walmartapis.com"
                : account.ApiBaseUrl!.TrimEnd('/');

            if (baseUrl.EndsWith("/v3", StringComparison.OrdinalIgnoreCase))
                return $"{baseUrl}/token";

            return $"{baseUrl}/v3/token";
        }
    }
}
