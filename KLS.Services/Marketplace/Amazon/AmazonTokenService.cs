using KLS.Contract.Interfaces;
using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Net.Http;
using System.Text;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;

namespace KLS.Services.Marketplace.Amazon
{
    public interface IAmazonTokenService
    {
        Task<string> GetAccessTokenAsync(int marketAccountId);
        Task<bool> TestConnectionAsync(int marketAccountId);
    }

    public class AmazonTokenService : BaseService, IAmazonTokenService
    {
        private readonly IHttpClientFactory _httpClientFactory;
        private static readonly SemaphoreSlim _tokenLock = new(1, 1);
        private const string LWA_TOKEN_URL = "https://api.amazon.com/auth/o2/token";

        public AmazonTokenService(IUnitOfWork uow, IHttpClientFactory httpClientFactory) : base(uow)
        {
            _httpClientFactory = httpClientFactory;
        }

        public async Task<string> GetAccessTokenAsync(int marketAccountId)
        {
            var account = Uow.MarketAccounts.GetById(marketAccountId);
            if (account == null) throw new InvalidOperationException("Market account not found");

            var settings = AmazonSettings.FromEncrypted(account.SettingsJson);
            if (string.IsNullOrEmpty(settings.RefreshToken))
                throw new InvalidOperationException("Refresh token not configured");

            // Return cached token if valid (60s buffer)
            if (settings.IsTokenValid) return settings.AccessToken!;

            await _tokenLock.WaitAsync();
            try
            {
                // Double-check after lock
                Uow.MarketAccounts.Reload(account);
                settings = AmazonSettings.FromEncrypted(account.SettingsJson);
                if (settings.IsTokenValid) return settings.AccessToken!;

                // Request new token
                var client = _httpClientFactory.CreateClient("AmazonLWA");
                var content = new FormUrlEncodedContent(new Dictionary<string, string>
                {
                    ["grant_type"] = "refresh_token",
                    ["refresh_token"] = settings.RefreshToken!,
                    ["client_id"] = settings.ClientId!,
                    ["client_secret"] = settings.ClientSecret!
                });

                var response = await client.PostAsync(LWA_TOKEN_URL, content);
                response.EnsureSuccessStatusCode();

                var json = await response.Content.ReadAsStringAsync();
                var tokenResponse = JsonSerializer.Deserialize<LwaTokenResponse>(json);

                // Cache token in SettingsJson (re-encrypt after updating)
                settings.AccessToken = tokenResponse!.access_token;
                settings.TokenExpiresAt = DateTime.UtcNow.AddSeconds(tokenResponse.expires_in);
                account.SettingsJson = settings.ToEncrypted();
                account.UpdatedAt = DateTime.UtcNow;
                Uow.MarketAccounts.Update(account);
                Uow.Commit();

                return settings.AccessToken;
            }
            finally { _tokenLock.Release(); }
        }

        public async Task<bool> TestConnectionAsync(int marketAccountId)
        {
            try
            {
                var token = await GetAccessTokenAsync(marketAccountId);
                return !string.IsNullOrEmpty(token);
            }
            catch { return false; }
        }
    }
}
