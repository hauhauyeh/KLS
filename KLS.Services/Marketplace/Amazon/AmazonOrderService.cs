using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Contract.Services.Marketplace;
using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Text.Json;
using System.Threading.Tasks;

namespace KLS.Services.Marketplace.Amazon
{
    public class AmazonOrderService : BaseService, IMarketplaceOrderService
    {
        private readonly IAmazonSpApiClient _client;
        private readonly IMarketSyncLogService _logService;

        public AmazonOrderService(IUnitOfWork uow, IAmazonSpApiClient client, IMarketSyncLogService logService) : base(uow)
        {
            _client = client;
            _logService = logService;
        }

        public async Task<int> PullOrdersAsync(int marketAccountId, DateTime? since = null)
        {
            var account = Uow.MarketAccounts.GetById(marketAccountId)
                ?? throw new Exception("Market account not found");
            var settings = AmazonSettings.FromEncrypted(account.SettingsJson);
            var createdAfter = since ?? DateTime.UtcNow.AddDays(-7);

            var syncLog = _logService.StartLog(marketAccountId, "order-pull");
            int imported = 0;

            try
            {
                var endpoint = $"/orders/v0/orders?MarketplaceIds={settings.MarketplaceId}&CreatedAfter={createdAfter:yyyy-MM-ddTHH:mm:ssZ}";
                var response = await _client.GetAsync<AmazonOrdersResponse>(marketAccountId, endpoint);

                if (response?.Orders?.Orders != null)
                {
                    foreach (var amazonOrder in response.Orders.Orders)
                    {
                        // Dedup check
                        var exists = Uow.MarketOrders.Exists(o =>
                            o.MarketAccountId == marketAccountId &&
                            o.ExternalOrderId == amazonOrder.AmazonOrderId);
                        if (exists) continue;

                        var order = new MarketOrder
                        {
                            MarketAccountId = marketAccountId,
                            ExternalOrderId = amazonOrder.AmazonOrderId!,
                            OrderDate = amazonOrder.PurchaseDate,
                            OrderStatus = amazonOrder.OrderStatus ?? "pending",
                            ShipToName = amazonOrder.ShippingAddress?.Name,
                            ShipToAddress1 = amazonOrder.ShippingAddress?.AddressLine1,
                            ShipToAddress2 = amazonOrder.ShippingAddress?.AddressLine2,
                            ShipToCity = amazonOrder.ShippingAddress?.City,
                            ShipToState = amazonOrder.ShippingAddress?.StateOrRegion,
                            ShipToPostalCode = amazonOrder.ShippingAddress?.PostalCode,
                            ShipToCountry = amazonOrder.ShippingAddress?.CountryCode,
                            CurrencyCode = amazonOrder.OrderTotal?.CurrencyCode,
                            OrderTotal = decimal.TryParse(amazonOrder.OrderTotal?.Amount, out var total) ? total : null,
                            RawJson = JsonSerializer.Serialize(amazonOrder)
                        };

                        Uow.MarketOrders.Add(order);
                        Uow.Commit();
                        imported++;

                        // TODO: Pull order items via /orders/v0/orders/{orderId}/orderItems
                        // and create MarketOrderItem records with SKU matching
                    }
                }

                _logService.CompleteLog(syncLog.MarketSyncLogId, true, imported, imported, 0);
                return imported;
            }
            catch (Exception ex)
            {
                _logService.CompleteLog(syncLog.MarketSyncLogId, false, 0, 0, 0, ex.Message);
                throw;
            }
        }
    }
}
