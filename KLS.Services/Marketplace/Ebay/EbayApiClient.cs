using KLS.Contract.Interfaces;
using KLS.Contract.Services.Marketplace.Ebay;
using KLS.Models;
using System;
using System.Collections.Concurrent;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;

namespace KLS.Services.Marketplace.Ebay
{
    public class EbayApiClient : IEbayApiClient
    {
        private readonly IEbayTokenService _tokenService;
        private readonly IHttpClientFactory _httpClientFactory;
        private readonly IUnitOfWork _uow;
        private static readonly ConcurrentDictionary<string, SemaphoreSlim> _rateLimiters = new();

        private const string ProductionBaseUrl = "https://api.ebay.com";
        private const string SandboxBaseUrl = "https://api.sandbox.ebay.com";

        public EbayApiClient(IEbayTokenService tokenService, IHttpClientFactory httpClientFactory, IUnitOfWork uow)
        {
            _tokenService = tokenService;
            _httpClientFactory = httpClientFactory;
            _uow = uow;
        }

        public Task<T?> GetAsync<T>(int marketAccountId, string endpoint) where T : class
            => ExecuteAsync<T>(marketAccountId, endpoint, HttpMethod.Get, null);

        public Task<T?> PostAsync<T>(int marketAccountId, string endpoint, object? body) where T : class
            => ExecuteAsync<T>(marketAccountId, endpoint, HttpMethod.Post, body);

        public Task<T?> PutAsync<T>(int marketAccountId, string endpoint, object? body) where T : class
            => ExecuteAsync<T>(marketAccountId, endpoint, HttpMethod.Put, body);

        public async Task<string?> PostRawAsync(int marketAccountId, string endpoint, object? body)
        {
            var (_, raw) = await ExecuteRawAsync(marketAccountId, endpoint, HttpMethod.Post, body);
            return raw;
        }

        public async Task<string?> PutRawAsync(int marketAccountId, string endpoint, object? body)
        {
            var (_, raw) = await ExecuteRawAsync(marketAccountId, endpoint, HttpMethod.Put, body);
            return raw;
        }

        public Task DeleteAsync(int marketAccountId, string endpoint)
            => ExecuteAsync<object>(marketAccountId, endpoint, HttpMethod.Delete, null);

        private async Task<T?> ExecuteAsync<T>(int marketAccountId, string endpoint, HttpMethod method, object? body) where T : class
        {
            var (content, _) = await ExecuteRawAsync(marketAccountId, endpoint, method, body);
            if (string.IsNullOrWhiteSpace(content)) return null;
            return JsonSerializer.Deserialize<T>(content, new JsonSerializerOptions { PropertyNameCaseInsensitive = true });
        }

        private async Task<(string? content, string? raw)> ExecuteRawAsync(
            int marketAccountId, string endpoint, HttpMethod method, object? body, int maxRetries = 3)
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
                    var settings = EbaySettings.FromEncrypted(account.SettingsJson);

                    var client = _httpClientFactory.CreateClient("EbayAPI");
                    var request = new HttpRequestMessage(method, BuildUrl(account, settings, endpoint));
                    request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);
                    request.Headers.Accept.Add(new MediaTypeWithQualityHeaderValue("application/json"));
                    request.Headers.AcceptLanguage.Add(new StringWithQualityHeaderValue("en-US"));

                    if (!string.IsNullOrWhiteSpace(settings.MarketplaceId))
                        request.Headers.Add("X-EBAY-C-MARKETPLACE-ID", settings.MarketplaceId);

                    if (body != null)
                    {
                        var json = JsonSerializer.Serialize(body, new JsonSerializerOptions
                        {
                            DefaultIgnoreCondition = System.Text.Json.Serialization.JsonIgnoreCondition.WhenWritingNull
                        });
                        request.Content = new StringContent(json, Encoding.UTF8, "application/json");
                    }

                    var response = await client.SendAsync(request);

                    if ((int)response.StatusCode == 429 && attempt < maxRetries)
                    {
                        var retryAfter = response.Headers.RetryAfter?.Delta?.TotalMilliseconds
                            ?? Math.Pow(2, attempt) * 1000;
                        await Task.Delay((int)retryAfter);
                        continue;
                    }

                    var content = await response.Content.ReadAsStringAsync();

                    if (!response.IsSuccessStatusCode)
                    {
                        throw new HttpRequestException(
                            $"eBay {method} {endpoint} failed ({(int)response.StatusCode}): {content}");
                    }

                    return (content, content);
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

            throw new Exception($"eBay request failed after {maxRetries + 1} attempts: {method} {endpoint}");
        }

        private static string BuildUrl(MarketAccount account, EbaySettings settings, string endpoint)
        {
            if (endpoint.StartsWith("http", StringComparison.OrdinalIgnoreCase))
                return endpoint;

            var baseUrl = !string.IsNullOrWhiteSpace(account.ApiBaseUrl)
                ? account.ApiBaseUrl!.TrimEnd('/')
                : (settings.IsSandbox ? SandboxBaseUrl : ProductionBaseUrl);

            return $"{baseUrl}{endpoint}";
        }

        private static string ExtractEndpointPattern(string endpoint)
        {
            var path = endpoint.Split('?', 2)[0];
            var parts = path.Split('/', StringSplitOptions.RemoveEmptyEntries);
            return parts.Length >= 2 ? $"/{parts[0]}/{parts[1]}" : path;
        }
    }
}
