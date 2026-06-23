using KLS.Contract.Interfaces;
using KLS.Contract.Services.Marketplace.ShipStation;
using KLS.Models;
using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Globalization;
using System.Net;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;

namespace KLS.Services.Marketplace.ShipStation
{
    public class ShipStationApiClient : IShipStationApiClient
    {
        private readonly IHttpClientFactory _httpClientFactory;
        private readonly IUnitOfWork _uow;
        private static readonly ConcurrentDictionary<int, SemaphoreSlim> _accountLimiters = new();

        private const string BaseUrl = "https://ssapi.shipstation.com";
        private const int MaxRetries = 3;

        private static readonly TimeZoneInfo PacificTz = ResolvePacificTimeZone();

        public ShipStationApiClient(IHttpClientFactory httpClientFactory, IUnitOfWork uow)
        {
            _httpClientFactory = httpClientFactory;
            _uow = uow;
        }

        public async Task<ShipStationOrdersResponse?> GetOrdersAsync(
            int marketAccountId,
            int page,
            int pageSize,
            DateTime? modifyDateStart,
            DateTime? createDateStart,
            int? storeId,
            CancellationToken ct = default)
        {
            var sb = new StringBuilder("/orders?");
            sb.Append($"page={page}&pageSize={pageSize}");
            if (modifyDateStart.HasValue)
                sb.Append($"&modifyDateStart={Uri.EscapeDataString(FormatPacific(modifyDateStart.Value))}");
            if (createDateStart.HasValue)
                sb.Append($"&createDateStart={Uri.EscapeDataString(FormatPacific(createDateStart.Value))}");
            if (storeId.HasValue)
                sb.Append($"&storeId={storeId.Value}");
            sb.Append("&sortBy=ModifyDate&sortDir=ASC");

            var responseBody = await ExecuteAsync(marketAccountId, HttpMethod.Get, sb.ToString(), ct);
            if (string.IsNullOrWhiteSpace(responseBody)) return null;

            return JsonSerializer.Deserialize<ShipStationOrdersResponse>(responseBody, new JsonSerializerOptions
            {
                PropertyNameCaseInsensitive = true
            });
        }

        public async Task<bool> TestConnectionAsync(int marketAccountId, CancellationToken ct = default)
        {
            try
            {
                var body = await ExecuteAsync(marketAccountId, HttpMethod.Get, "/orders?pageSize=1", null, ct);
                return !string.IsNullOrWhiteSpace(body);
            }
            catch
            {
                return false;
            }
        }

        public async Task<ShipStationProduct?> GetProductAsync(int marketAccountId, int productId, CancellationToken ct = default)
        {
            var body = await ExecuteAsync(marketAccountId, HttpMethod.Get, $"/products/{productId}", null, ct);
            if (string.IsNullOrWhiteSpace(body)) return null;
            return JsonSerializer.Deserialize<ShipStationProduct>(body, new JsonSerializerOptions
            {
                PropertyNameCaseInsensitive = true
            });
        }

        public async Task<bool> UpdateProductUpcAsync(int marketAccountId, int productId, string upc, CancellationToken ct = default)
        {
            var product = await GetProductAsync(marketAccountId, productId, ct);
            if (product == null) return false;

            product.upc = upc;

            var response = await ExecuteAsync(marketAccountId, HttpMethod.Put, $"/products/{productId}", product, ct);
            return !string.IsNullOrWhiteSpace(response);
        }

        public async Task<ShipStationOrder?> GetOrderByIdAsync(int marketAccountId, int orderId, CancellationToken ct = default)
        {
            var body = await ExecuteAsync(marketAccountId, HttpMethod.Get, $"/orders/{orderId}", null, ct);
            if (string.IsNullOrWhiteSpace(body)) return null;
            return JsonSerializer.Deserialize<ShipStationOrder>(body, new JsonSerializerOptions
            {
                PropertyNameCaseInsensitive = true
            });
        }

        public async Task<string?> GetByResourceUrlAsync(int marketAccountId, string resourceUrl, CancellationToken ct = default)
        {
            if (!resourceUrl.StartsWith(BaseUrl, StringComparison.OrdinalIgnoreCase))
                throw new InvalidOperationException("Invalid resource URL: must originate from ShipStation API");

            var endpoint = resourceUrl.Substring(BaseUrl.Length);
            return await ExecuteAsync(marketAccountId, HttpMethod.Get, endpoint, null, ct);
        }

        public async Task<int> SubscribeWebhookAsync(int marketAccountId, string targetUrl, string eventType, int? storeId = null, CancellationToken ct = default)
        {
            var marketAccount = _uow.MarketAccounts.GetById(marketAccountId);

            var request = new ShipStationWebhookSubscribeRequest
            {
                TargetUrl = targetUrl,
                Event = eventType,
                StoreId = storeId,
                FriendlyName = $"{marketAccount?.StoreCode} {eventType}"
            };

            var body = await ExecuteAsync(marketAccountId, HttpMethod.Post, "/webhooks/subscribe", request, ct);
            if (string.IsNullOrWhiteSpace(body))
                throw new InvalidOperationException("Empty response from ShipStation webhook subscribe");

            var response = JsonSerializer.Deserialize<ShipStationWebhookSubscribeResponse>(body, new JsonSerializerOptions
            {
                PropertyNameCaseInsensitive = true
            });
            return response?.id ?? 0;
        }

        public async Task<bool> UnsubscribeWebhookAsync(int marketAccountId, int webhookId, CancellationToken ct = default)
        {
            try
            {
                await ExecuteAsync(marketAccountId, HttpMethod.Delete, $"/webhooks/{webhookId}", null, ct);
                return true;
            }
            catch
            {
                return false;
            }
        }

        public async Task<List<ShipStationWebhookInfo>> ListWebhooksAsync(int marketAccountId, CancellationToken ct = default)
        {
            var body = await ExecuteAsync(marketAccountId, HttpMethod.Get, "/webhooks", null, ct);
            if (string.IsNullOrWhiteSpace(body)) return new List<ShipStationWebhookInfo>();

            var response = JsonSerializer.Deserialize<ShipStationWebhooksListResponse>(body, new JsonSerializerOptions
            {
                PropertyNameCaseInsensitive = true
            });
            return response?.webhooks ?? new List<ShipStationWebhookInfo>();
        }

        private Task<string?> ExecuteAsync(int marketAccountId, HttpMethod method, string endpoint, CancellationToken ct)
        {
            return ExecuteAsync(marketAccountId, method, endpoint, null, ct);
        }

        private async Task<string?> ExecuteAsync(int marketAccountId, HttpMethod method, string endpoint, object? body, CancellationToken ct)
        {
            var limiter = _accountLimiters.GetOrAdd(marketAccountId, _ => new SemaphoreSlim(1, 1));

            for (int attempt = 0; attempt <= MaxRetries; attempt++)
            {
                await limiter.WaitAsync(ct);
                try
                {
                    var account = _uow.MarketAccounts.GetById(marketAccountId)
                        ?? throw new InvalidOperationException("Market account not found");
                    var settings = ShipStationSettings.FromEncrypted(account.SettingsJson);
                    if (string.IsNullOrWhiteSpace(settings.ApiKey) || string.IsNullOrWhiteSpace(settings.ApiSecret))
                        throw new InvalidOperationException("ShipStation ApiKey/ApiSecret not configured");

                    var client = _httpClientFactory.CreateClient("ShipStation");
                    var request = new HttpRequestMessage(method, BaseUrl + endpoint);
                    var basic = Convert.ToBase64String(Encoding.UTF8.GetBytes($"{settings.ApiKey}:{settings.ApiSecret}"));
                    request.Headers.Authorization = new AuthenticationHeaderValue("Basic", basic);
                    request.Headers.Accept.Add(new MediaTypeWithQualityHeaderValue("application/json"));

                    if (body != null)
                    {
                        var json = JsonSerializer.Serialize(body, new JsonSerializerOptions
                        {
                            DefaultIgnoreCondition = System.Text.Json.Serialization.JsonIgnoreCondition.WhenWritingNull
                        });
                        request.Content = new StringContent(json, Encoding.UTF8, new MediaTypeHeaderValue("application/json"));
                    }

                    HttpResponseMessage response;
                    try
                    {
                        response = await client.SendAsync(request, ct);
                    }
                    catch (TaskCanceledException) when (!ct.IsCancellationRequested && attempt < MaxRetries)
                    {
                        await Task.Delay(Backoff(attempt), ct);
                        continue;
                    }
                    catch (HttpRequestException) when (attempt < MaxRetries)
                    {
                        await Task.Delay(Backoff(attempt), ct);
                        continue;
                    }

                    // 401 — no retry
                    if (response.StatusCode == HttpStatusCode.Unauthorized)
                    {
                        var err = await SafeRead(response);
                        throw new InvalidOperationException($"Invalid API credentials (401): {err}");
                    }

                    // 429
                    if ((int)response.StatusCode == 429 && attempt < MaxRetries)
                    {
                        var waitSeconds = ReadResetSeconds(response) ?? 60;
                        await Task.Delay(TimeSpan.FromSeconds(waitSeconds), ct);
                        continue;
                    }

                    // 5xx — backoff + retry
                    if ((int)response.StatusCode >= 500 && attempt < MaxRetries)
                    {
                        await Task.Delay(Backoff(attempt), ct);
                        continue;
                    }

                    response.EnsureSuccessStatusCode();
                    var responseText = await response.Content.ReadAsStringAsync(ct);

                    // Post-response soft throttle: only if header is present AND remaining < 5
                    if (TryReadRemaining(response, out var remaining) && remaining < 5)
                    {
                        await Task.Delay(TimeSpan.FromSeconds(2), ct);
                    }

                    return responseText;
                }
                finally
                {
                    limiter.Release();
                }
            }

            throw new Exception($"ShipStation {method} {endpoint} failed after {MaxRetries + 1} attempts");
        }

        private static bool TryReadRemaining(HttpResponseMessage response, out int remaining)
        {
            remaining = 0;
            if (response.Headers.TryGetValues("X-Rate-Limit-Remaining", out var values))
            {
                foreach (var v in values)
                {
                    if (int.TryParse(v, out var parsed)) { remaining = parsed; return true; }
                }
            }
            return false;
        }

        private static int? ReadResetSeconds(HttpResponseMessage response)
        {
            if (response.Headers.TryGetValues("X-Rate-Limit-Reset", out var values))
            {
                foreach (var v in values)
                    if (int.TryParse(v, out var parsed)) return parsed;
            }
            return null;
        }

        private static async Task<string> SafeRead(HttpResponseMessage r)
        {
            try { return await r.Content.ReadAsStringAsync(); } catch { return ""; }
        }

        private static TimeSpan Backoff(int attempt)
        {
            return TimeSpan.FromSeconds(Math.Pow(2, attempt));
        }

        private static string FormatPacific(DateTime utc)
        {
            var local = TimeZoneInfo.ConvertTimeFromUtc(
                utc.Kind == DateTimeKind.Utc ? utc : DateTime.SpecifyKind(utc, DateTimeKind.Utc),
                PacificTz);
            return local.ToString("yyyy-MM-dd HH:mm:ss", CultureInfo.InvariantCulture);
        }

        public static DateTime PacificToUtc(DateTime pacific)
        {
            var unspecified = DateTime.SpecifyKind(pacific, DateTimeKind.Unspecified);
            return TimeZoneInfo.ConvertTimeToUtc(unspecified, PacificTz);
        }

        private static TimeZoneInfo ResolvePacificTimeZone()
        {
            try { return TimeZoneInfo.FindSystemTimeZoneById("Pacific Standard Time"); } catch { }
            try { return TimeZoneInfo.FindSystemTimeZoneById("America/Los_Angeles"); } catch { }
            return TimeZoneInfo.Utc;
        }
    }
}
