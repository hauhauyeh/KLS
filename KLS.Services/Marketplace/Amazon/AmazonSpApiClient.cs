using KLS.Contract.Interfaces;
using KLS.Models;
using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Linq;
using System.Net.Http;
using System.Text;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;

namespace KLS.Services.Marketplace.Amazon
{
    public interface IAmazonSpApiClient
    {
        Task<T?> GetAsync<T>(int marketAccountId, string endpoint) where T : class;
        Task<T?> PostAsync<T>(int marketAccountId, string endpoint, object body) where T : class;
        Task<T?> PutAsync<T>(int marketAccountId, string endpoint, object body) where T : class;
        Task<T?> PatchAsync<T>(int marketAccountId, string endpoint, object body) where T : class;
        Task DeleteAsync(int marketAccountId, string endpoint);
    }

    public class AmazonSpApiClient : IAmazonSpApiClient
    {
        private readonly IAmazonTokenService _tokenService;
        private readonly IHttpClientFactory _httpClientFactory;
        private readonly IUnitOfWork _uow;

        private static readonly Dictionary<string, string> RegionEndpoints = new()
        {
            ["NA"] = "https://sellingpartnerapi-na.amazon.com",
            ["EU"] = "https://sellingpartnerapi-eu.amazon.com",
            ["FE"] = "https://sellingpartnerapi-fe.amazon.com"
        };

        private static readonly ConcurrentDictionary<string, SemaphoreSlim> _rateLimiters = new();

        public AmazonSpApiClient(IAmazonTokenService tokenService, IHttpClientFactory httpClientFactory, IUnitOfWork uow)
        {
            _tokenService = tokenService;
            _httpClientFactory = httpClientFactory;
            _uow = uow;
        }

        public async Task<T?> GetAsync<T>(int marketAccountId, string endpoint) where T : class
            => await ExecuteAsync<T>(marketAccountId, endpoint, HttpMethod.Get, null);

        public async Task<T?> PostAsync<T>(int marketAccountId, string endpoint, object body) where T : class
            => await ExecuteAsync<T>(marketAccountId, endpoint, HttpMethod.Post, body);

        public async Task<T?> PutAsync<T>(int marketAccountId, string endpoint, object body) where T : class
            => await ExecuteAsync<T>(marketAccountId, endpoint, HttpMethod.Put, body);

        public async Task<T?> PatchAsync<T>(int marketAccountId, string endpoint, object body) where T : class
            => await ExecuteAsync<T>(marketAccountId, endpoint, HttpMethod.Patch, body);

        public async Task DeleteAsync(int marketAccountId, string endpoint)
            => await ExecuteAsync<object>(marketAccountId, endpoint, HttpMethod.Delete, null);

        private async Task<T?> ExecuteAsync<T>(int marketAccountId, string endpoint, HttpMethod method, object? body, int maxRetries = 3) where T : class
        {
            var limiterKey = ExtractEndpointPattern(endpoint);
            var limiter = _rateLimiters.GetOrAdd(limiterKey, _ => new SemaphoreSlim(1, 1));

            for (int attempt = 0; attempt <= maxRetries; attempt++)
            {
                await limiter.WaitAsync();
                try
                {
                    var token = await _tokenService.GetAccessTokenAsync(marketAccountId);
                    var account = _uow.MarketAccounts.GetById(marketAccountId)
                        ?? throw new Exception("Market account not found");
                    var settings = AmazonSettings.FromEncrypted(account.SettingsJson);
                    var baseUrl = RegionEndpoints.GetValueOrDefault(account.RegionCode ?? "NA", RegionEndpoints["NA"]);

                    var client = _httpClientFactory.CreateClient("AmazonSPAPI");
                    var request = new HttpRequestMessage(method, $"{baseUrl}{endpoint}");
                    request.Headers.Add("x-amz-access-token", token);

                    if (body != null)
                        request.Content = new StringContent(
                            JsonSerializer.Serialize(body), Encoding.UTF8, "application/json");

                    var response = await client.SendAsync(request);

                    // Handle rate limiting
                    if ((int)response.StatusCode == 429)
                    {
                        var retryAfter = response.Headers.RetryAfter?.Delta?.TotalMilliseconds
                            ?? Math.Pow(2, attempt) * 1000;
                        await Task.Delay((int)retryAfter);
                        continue;
                    }

                    response.EnsureSuccessStatusCode();
                    var content = await response.Content.ReadAsStringAsync();
                    if (typeof(T) == typeof(object) && string.IsNullOrEmpty(content)) return null;
                    return JsonSerializer.Deserialize<T>(content, new JsonSerializerOptions { PropertyNameCaseInsensitive = true });
                }
                catch (HttpRequestException) when (attempt < maxRetries)
                {
                    await Task.Delay((int)(Math.Pow(2, attempt) * 1000));
                }
                finally { limiter.Release(); }
            }
            throw new Exception($"SP-API request failed after {maxRetries + 1} attempts: {method} {endpoint}");
        }

        private static string ExtractEndpointPattern(string endpoint)
        {
            var parts = endpoint.Split('/', StringSplitOptions.RemoveEmptyEntries);
            return parts.Length >= 2 ? $"/{parts[0]}/{parts[1]}" : endpoint;
        }
    }
}
