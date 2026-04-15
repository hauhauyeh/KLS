using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Contract.Services.Marketplace.Amazon;
using KLS.Contract.Services.Marketplace;
using KLS.Common;
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
                        if (string.IsNullOrWhiteSpace(amazonOrder.AmazonOrderId))
                            continue;

                        var existing = Uow.MarketOrders.Find(o =>
                            o.MarketAccountId == marketAccountId &&
                            o.ExternalOrderId == amazonOrder.AmazonOrderId).FirstOrDefault();

                        var order = existing ?? new MarketOrder
                        {
                            MarketAccountId = marketAccountId,
                            ExternalOrderId = amazonOrder.AmazonOrderId!
                        };

                        order.OrderDate = amazonOrder.PurchaseDate;
                        order.OrderStatus = amazonOrder.OrderStatus ?? MarketInternalOrderStatus.Pending.ToValue();
                        order.ShipToName = amazonOrder.ShippingAddress?.Name;
                        order.ShipToAddress1 = amazonOrder.ShippingAddress?.AddressLine1;
                        order.ShipToAddress2 = amazonOrder.ShippingAddress?.AddressLine2;
                        order.ShipToCity = amazonOrder.ShippingAddress?.City;
                        order.ShipToState = amazonOrder.ShippingAddress?.StateOrRegion;
                        order.ShipToPostalCode = amazonOrder.ShippingAddress?.PostalCode;
                        order.ShipToCountry = amazonOrder.ShippingAddress?.CountryCode;
                        order.CurrencyCode = amazonOrder.OrderTotal?.CurrencyCode;
                        order.OrderTotal = decimal.TryParse(amazonOrder.OrderTotal?.Amount, out var total) ? total : null;
                        order.RawJson = JsonSerializer.Serialize(amazonOrder);
                        order.LastSyncAt = DateTime.UtcNow;
                        order.LastSyncStatus = MarketSyncStatus.Success.ToValue();
                        order.LastError = null;
                        order.UpdatedAt = existing == null ? order.UpdatedAt : DateTime.UtcNow;

                        if (existing == null) Uow.MarketOrders.Add(order);
                        else Uow.MarketOrders.Update(order);
                        Uow.Commit();

                        await UpsertOrderItemsAsync(order, amazonOrder.AmazonOrderId);
                        imported++;
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

        private async Task UpsertOrderItemsAsync(MarketOrder order, string amazonOrderId)
        {
            string? nextToken = null;

            do
            {
                var endpoint = string.IsNullOrWhiteSpace(nextToken)
                    ? $"/orders/v0/orders/{amazonOrderId}/orderItems"
                    : $"/orders/v0/orders/{amazonOrderId}/orderItems?NextToken={Uri.EscapeDataString(nextToken)}";

                var response = await _client.GetAsync<AmazonOrderItemsResponse>(order.MarketAccountId, endpoint);
                if (response == null) break;

                foreach (var amazonItem in response.GetItems())
                {
                    if (string.IsNullOrWhiteSpace(amazonItem.OrderItemId))
                        continue;

                    var existingItem = Uow.MarketOrderItems.Find(i =>
                        i.MarketOrderId == order.MarketOrderId &&
                        i.ExternalLineId == amazonItem.OrderItemId).FirstOrDefault();

                    var orderItem = existingItem ?? new MarketOrderItem
                    {
                        MarketOrderId = order.MarketOrderId,
                        ExternalLineId = amazonItem.OrderItemId
                    };

                    var qty = amazonItem.QuantityOrdered ?? 0;
                    var unitPrice = ParseMoney(amazonItem.ItemPrice);
                    var taxAmount = ParseMoney(amazonItem.ItemTax);
                    var discountAmount = ParseMoney(amazonItem.PromotionDiscount);

                    orderItem.ExternalSku = amazonItem.SellerSKU;
                    orderItem.ExternalListingId = amazonItem.ASIN;
                    orderItem.ExternalItemName = amazonItem.Title;
                    orderItem.Qty = qty;
                    orderItem.UnitPrice = unitPrice;
                    orderItem.TaxAmount = taxAmount;
                    orderItem.DiscountAmount = discountAmount;
                    orderItem.LineTotal = (unitPrice ?? 0m) * qty;
                    orderItem.MatchStatus = existingItem?.MatchStatus ?? "unmatched";
                    orderItem.UpdatedAt = existingItem == null ? orderItem.UpdatedAt : DateTime.UtcNow;

                    if (existingItem == null) Uow.MarketOrderItems.Add(orderItem);
                    else Uow.MarketOrderItems.Update(orderItem);
                }

                Uow.Commit();
                nextToken = response.GetNextToken();
            }
            while (!string.IsNullOrWhiteSpace(nextToken));
        }

        private static decimal? ParseMoney(AmazonMoney? money)
        {
            return decimal.TryParse(money?.Amount, out var value) ? value : null;
        }
    }
}
