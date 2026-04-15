using KLS.Contract.Interfaces;
using KLS.Contract.Services.Marketplace.Walmart;
using KLS.Models;
using System;
using System.Collections.Concurrent;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;

namespace KLS.Services.Marketplace.Walmart
{
    public class WalmartApiClient : IWalmartApiClient
    {
        private readonly IWalmartTokenService _tokenService;
        private readonly IHttpClientFactory _httpClientFactory;
        private readonly IUnitOfWork _uow;
        private static readonly ConcurrentDictionary<string, SemaphoreSlim> _rateLimiters = new();

        public WalmartApiClient(IWalmartTokenService tokenService, IHttpClientFactory httpClientFactory, IUnitOfWork uow)
        {
            _tokenService = tokenService;
            _httpClientFactory = httpClientFactory;
            _uow = uow;
        }

        public Task<T?> GetAsync<T>(int marketAccountId, string endpoint) where T : class
            => ExecuteAsync<T>(marketAccountId, endpoint, HttpMethod.Get, null);

        public Task<T?> PostAsync<T>(int marketAccountId, string endpoint, object body) where T : class
            => ExecuteAsync<T>(marketAccountId, endpoint, HttpMethod.Post, body);

        public Task<T?> PutAsync<T>(int marketAccountId, string endpoint, object body) where T : class
            => ExecuteAsync<T>(marketAccountId, endpoint, HttpMethod.Put, body);

        public Task DeleteAsync(int marketAccountId, string endpoint)
            => ExecuteAsync<object>(marketAccountId, endpoint, HttpMethod.Delete, null);

        private async Task<T?> ExecuteAsync<T>(int marketAccountId, string endpoint, HttpMethod method, object? body, int maxRetries = 3) where T : class
        {
            var limiterKey = $"{marketAccountId}:{ExtractEndpointPattern(endpoint)}";
            var limiter = _rateLimiters.GetOrAdd(limiterKey, _ => new SemaphoreSlim(1, 1));

            for (int attempt = 0; attempt <= maxRetries; attempt++)
            {
                await limiter.WaitAsync();
                try
                {
                    var token = await _tokenService.GetAccessTokenAsync(marketAccountId);
                    var account = _uow.MarketAccounts.GetById(marketAccountId)
                        ?? throw new InvalidOperationException("Market account not found");
                    var client = _httpClientFactory.CreateClient("WalmartAPI");
                    var request = new HttpRequestMessage(method, BuildUrl(account, endpoint));
                    request.Headers.Add("WM_SEC.ACCESS_TOKEN", token);
                    request.Headers.Add("WM_SVC.NAME", "Walmart Marketplace");
                    request.Headers.Add("WM_QOS.CORRELATION_ID", Guid.NewGuid().ToString("N"));
                    request.Headers.Accept.Add(new MediaTypeWithQualityHeaderValue("application/json"));

                    if (body != null)
                    {
                        request.Content = new StringContent(
                            JsonSerializer.Serialize(body),
                            Encoding.UTF8,
                            "application/json");
                    }

                    var response = await client.SendAsync(request);
                    if ((int)response.StatusCode == 429 && attempt < maxRetries)
                    {
                        var retryAfter = response.Headers.RetryAfter?.Delta?.TotalMilliseconds
                            ?? Math.Pow(2, attempt) * 1000;
                        await Task.Delay((int)retryAfter);
                        continue;
                    }

                    response.EnsureSuccessStatusCode();
                    var content = await response.Content.ReadAsStringAsync();

                    if (typeof(T) == typeof(object) && string.IsNullOrWhiteSpace(content))
                        return null;

                    return string.IsNullOrWhiteSpace(content)
                        ? null
                        : JsonSerializer.Deserialize<T>(content, new JsonSerializerOptions
                        {
                            PropertyNameCaseInsensitive = true
                        });
                }
                catch (HttpRequestException) when (attempt < maxRetries)
                {
                    await Task.Delay((int)(Math.Pow(2, attempt) * 1000));
                }
                finally
                {
                    limiter.Release();
                }
            }

            throw new Exception($"Walmart request failed after {maxRetries + 1} attempts: {method} {endpoint}");
        }

        private static string BuildUrl(MarketAccount account, string endpoint)
        {
            var baseUrl = string.IsNullOrWhiteSpace(account.ApiBaseUrl)
                ? "https://marketplace.walmartapis.com"
                : account.ApiBaseUrl!.TrimEnd('/');

            return endpoint.StartsWith("http", StringComparison.OrdinalIgnoreCase)
                ? endpoint
                : $"{baseUrl}{endpoint}";
        }

        private static string ExtractEndpointPattern(string endpoint)
        {
            var path = endpoint.Split('?', 2)[0];
            var parts = path.Split('/', StringSplitOptions.RemoveEmptyEntries);
            return parts.Length >= 2 ? $"/{parts[0]}/{parts[1]}" : path;
        }
    }
}
