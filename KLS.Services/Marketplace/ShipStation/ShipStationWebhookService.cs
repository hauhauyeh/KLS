using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Contract.Services.Marketplace.ShipStation;
using KLS.Models;
using System;
using System.Linq;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;

namespace KLS.Services.Marketplace.ShipStation
{
    public class ShipStationWebhookService : BaseService
    {
        private readonly IShipStationApiClient _client;
        private readonly IMarketSyncLogService _logService;

        private static readonly JsonSerializerOptions _jsonOptions = new()
        {
            PropertyNameCaseInsensitive = true
        };

        public ShipStationWebhookService(IUnitOfWork uow, IShipStationApiClient client, IMarketSyncLogService logService)
            : base(uow)
        {
            _client = client;
            _logService = logService;
        }

        public async Task ProcessWebhookAsync(int marketAccountId, string secret, ShipStationWebhookPayload payload, CancellationToken ct)
        {
            var account = Uow.MarketAccounts.GetById(marketAccountId);
            if (account == null) return;

            var settings = ShipStationSettings.FromEncrypted(account.SettingsJson);
            if (string.IsNullOrEmpty(settings.WebhookSecret) || !string.Equals(secret, settings.WebhookSecret, StringComparison.Ordinal))
                return;

            if (string.IsNullOrEmpty(payload.resource_url) || string.IsNullOrEmpty(payload.resource_type))
                return;

            var syncType = $"webhook-{payload.resource_type}";
            var syncLog = _logService.StartLog(marketAccountId, syncType);
            int processed = 0, succeeded = 0, failed = 0;

            try
            {
                var responseBody = await _client.GetByResourceUrlAsync(marketAccountId, payload.resource_url, ct);
                if (string.IsNullOrWhiteSpace(responseBody))
                {
                    _logService.CompleteLog(syncLog.MarketSyncLogId, true, 0, 0, 0, "empty response from resource_url");
                    return;
                }

                switch (payload.resource_type)
                {
                    case "ORDER_NOTIFY":
                        (processed, succeeded, failed) = ProcessOrderNotify(marketAccountId, responseBody);
                        break;
                    case "SHIP_NOTIFY":
                        (processed, succeeded, failed) = ProcessShipNotify(marketAccountId, responseBody);
                        break;
                }

                _logService.CompleteLog(syncLog.MarketSyncLogId, failed == 0, processed, succeeded, failed,
                    failed > 0 ? $"{failed} order(s) failed" : null);
            }
            catch (Exception ex)
            {
                _logService.CompleteLog(syncLog.MarketSyncLogId, false, processed, succeeded, failed, ex.Message);
            }
        }

        private (int processed, int succeeded, int failed) ProcessOrderNotify(int marketAccountId, string responseBody)
        {
            var response = JsonSerializer.Deserialize<ShipStationOrdersResponse>(responseBody, _jsonOptions);
            if (response?.orders == null || response.orders.Count == 0)
                return (0, 0, 0);

            int processed = 0, succeeded = 0, failed = 0;

            foreach (var order in response.orders)
            {
                processed++;
                try
                {
                    var externalOrderId = order.orderId.ToString();
                    var existing = Uow.MarketOrders.Find(o =>
                        o.MarketAccountId == marketAccountId &&
                        o.ExternalOrderId == externalOrderId).FirstOrDefault();

                    if (existing == null) continue;

                    existing.OrderStatus = order.orderStatus ?? existing.OrderStatus;
                    existing.LastSyncAt = DateTime.UtcNow;
                    existing.LastSyncStatus = MarketSyncStatus.Success.ToValue();
                    existing.UpdatedAt = DateTime.UtcNow;
                    Uow.MarketOrders.Update(existing);
                    succeeded++;
                }
                catch
                {
                    failed++;
                }
            }

            if (succeeded > 0) Uow.Commit();
            return (processed, succeeded, failed);
        }

        private (int processed, int succeeded, int failed) ProcessShipNotify(int marketAccountId, string responseBody)
        {
            var response = JsonSerializer.Deserialize<ShipStationShipmentsResponse>(responseBody, _jsonOptions);
            if (response?.shipments == null || response.shipments.Count == 0)
                return (0, 0, 0);

            int processed = 0, succeeded = 0, failed = 0;

            foreach (var shipment in response.shipments)
            {
                if (shipment.voided == true) continue;

                processed++;
                try
                {
                    var externalOrderId = shipment.orderId.ToString();
                    var existing = Uow.MarketOrders.Find(o =>
                        o.MarketAccountId == marketAccountId &&
                        o.ExternalOrderId == externalOrderId).FirstOrDefault();

                    if (existing == null) continue;

                    existing.OrderStatus = "shipped";
                    existing.LastSyncAt = DateTime.UtcNow;
                    existing.LastSyncStatus = MarketSyncStatus.Success.ToValue();
                    existing.UpdatedAt = DateTime.UtcNow;
                    Uow.MarketOrders.Update(existing);
                    succeeded++;
                }
                catch
                {
                    failed++;
                }
            }

            if (succeeded > 0) Uow.Commit();
            return (processed, succeeded, failed);
        }

        public async Task<(int orderNotifyId, int shipNotifyId)> SubscribeAsync(int marketAccountId, string baseWebhookUrl, CancellationToken ct)
        {
            var account = Uow.MarketAccounts.GetById(marketAccountId)
                ?? throw new InvalidOperationException("Market account not found");

            var settings = ShipStationSettings.FromEncrypted(account.SettingsJson);

            if (string.IsNullOrEmpty(settings.WebhookSecret))
                settings.WebhookSecret = Guid.NewGuid().ToString("N");

            var targetUrl = $"{baseWebhookUrl}/{marketAccountId}/{settings.WebhookSecret}";

            var orderNotifyId = await _client.SubscribeWebhookAsync(marketAccountId, targetUrl, "ORDER_NOTIFY", settings.StoreId, ct);
            var shipNotifyId = await _client.SubscribeWebhookAsync(marketAccountId, targetUrl, "SHIP_NOTIFY", settings.StoreId, ct);

            settings.OrderNotifyWebhookId = orderNotifyId;
            settings.ShipNotifyWebhookId = shipNotifyId;

            account.SettingsJson = settings.ToEncrypted();
            account.UpdatedAt = DateTime.UtcNow;
            Uow.MarketAccounts.Update(account);
            Uow.Commit();

            return (orderNotifyId, shipNotifyId);
        }

        public async Task UnsubscribeAsync(int marketAccountId, CancellationToken ct)
        {
            var account = Uow.MarketAccounts.GetById(marketAccountId)
                ?? throw new InvalidOperationException("Market account not found");

            var settings = ShipStationSettings.FromEncrypted(account.SettingsJson);

            if (settings.OrderNotifyWebhookId.HasValue)
                await _client.UnsubscribeWebhookAsync(marketAccountId, settings.OrderNotifyWebhookId.Value, ct);

            if (settings.ShipNotifyWebhookId.HasValue)
                await _client.UnsubscribeWebhookAsync(marketAccountId, settings.ShipNotifyWebhookId.Value, ct);

            settings.OrderNotifyWebhookId = null;
            settings.ShipNotifyWebhookId = null;
            settings.WebhookSecret = null;

            account.SettingsJson = settings.ToEncrypted();
            account.UpdatedAt = DateTime.UtcNow;
            Uow.MarketAccounts.Update(account);
            Uow.Commit();
        }

        public bool HasActiveSubscription(int marketAccountId)
        {
            var account = Uow.MarketAccounts.GetById(marketAccountId);
            if (account == null) return false;

            var settings = ShipStationSettings.FromEncrypted(account.SettingsJson);
            return settings.OrderNotifyWebhookId.HasValue || settings.ShipNotifyWebhookId.HasValue;
        }
    }
}
