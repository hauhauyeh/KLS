using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Contract.Services.Marketplace;
using KLS.Contract.Services.Marketplace.Walmart;
using KLS.Common;
using KLS.Models;
using System;
using System.Linq;
using System.Text.Json;
using System.Threading.Tasks;

namespace KLS.Services.Marketplace.Walmart
{
    public class WalmartOrderService : BaseService, IMarketplaceOrderService
    {
        private readonly IWalmartApiClient _client;
        private readonly IMarketSyncLogService _logService;

        public WalmartOrderService(IUnitOfWork uow, IWalmartApiClient client, IMarketSyncLogService logService) : base(uow)
        {
            _client = client;
            _logService = logService;
        }

        public async Task<int> PullOrdersAsync(int marketAccountId, DateTime? since = null)
        {
            var from = since ?? DateTime.UtcNow.AddDays(-7);
            var syncLog = _logService.StartLog(marketAccountId, "order-pull");
            int importedOrUpdated = 0;
            int failed = 0;
            string? nextCursor = null;

            try
            {
                do
                {
                    var endpoint = string.IsNullOrWhiteSpace(nextCursor)
                        ? $"/v3/orders?createdStartDate={Uri.EscapeDataString(from.ToString("yyyy-MM-ddTHH:mm:ssZ"))}"
                        : $"/v3/orders?createdStartDate={Uri.EscapeDataString(from.ToString("yyyy-MM-ddTHH:mm:ssZ"))}&nextCursor={Uri.EscapeDataString(nextCursor)}";

                    var response = await _client.GetAsync<WalmartOrdersResponse>(marketAccountId, endpoint);
                    if (response == null) break;

                    foreach (var wOrder in response.GetOrders())
                    {
                        try
                        {
                            if (string.IsNullOrWhiteSpace(wOrder.PurchaseOrderId))
                                continue;

                            var existing = Uow.MarketOrders.Find(o =>
                                o.MarketAccountId == marketAccountId &&
                                o.ExternalOrderId == wOrder.PurchaseOrderId).FirstOrDefault();

                            var order = existing ?? new MarketOrder
                            {
                                MarketAccountId = marketAccountId,
                                ExternalOrderId = wOrder.PurchaseOrderId
                            };

                            order.ExternalOrderNo = wOrder.CustomerOrderId;
                            order.OrderDate = wOrder.OrderDate;
                            order.OrderStatus = wOrder.Status ?? MarketInternalOrderStatus.Pending.ToValue();
                            order.CustomerEmail = wOrder.CustomerEmailId;
                            order.ShipToName = wOrder.ShippingInfo?.PostalAddress?.Name;
                            order.ShipToAddress1 = wOrder.ShippingInfo?.PostalAddress?.Address1;
                            order.ShipToAddress2 = wOrder.ShippingInfo?.PostalAddress?.Address2;
                            order.ShipToCity = wOrder.ShippingInfo?.PostalAddress?.City;
                            order.ShipToState = wOrder.ShippingInfo?.PostalAddress?.State;
                            order.ShipToPostalCode = wOrder.ShippingInfo?.PostalAddress?.PostalCode;
                            order.ShipToCountry = wOrder.ShippingInfo?.PostalAddress?.Country;
                            order.Phone = wOrder.ShippingInfo?.Phone;
                            order.CurrencyCode = ResolveCurrency(wOrder);
                            order.OrderTotal = wOrder.OrderTotal;
                            order.RawJson = JsonSerializer.Serialize(wOrder);
                            order.LastSyncAt = DateTime.UtcNow;
                            order.LastSyncStatus = MarketSyncStatus.Success.ToValue();
                            order.LastError = null;
                            order.UpdatedAt = existing == null ? order.UpdatedAt : DateTime.UtcNow;

                            if (existing == null) Uow.MarketOrders.Add(order);
                            else Uow.MarketOrders.Update(order);
                            Uow.Commit();

                            UpsertOrderItems(order, wOrder);
                            importedOrUpdated++;
                        }
                        catch
                        {
                            failed++;
                        }
                    }

                    nextCursor = response.GetNextCursor();
                }
                while (!string.IsNullOrWhiteSpace(nextCursor));

                _logService.CompleteLog(syncLog.MarketSyncLogId, failed == 0, importedOrUpdated + failed, importedOrUpdated, failed);
                return importedOrUpdated;
            }
            catch (Exception ex)
            {
                _logService.CompleteLog(syncLog.MarketSyncLogId, false, importedOrUpdated + failed, importedOrUpdated, failed, ex.Message);
                throw;
            }
        }

        private void UpsertOrderItems(MarketOrder order, WalmartOrder wOrder)
        {
            foreach (var line in wOrder.GetOrderLines())
            {
                if (string.IsNullOrWhiteSpace(line.LineNumber))
                    continue;

                var existing = Uow.MarketOrderItems.Find(i =>
                    i.MarketOrderId == order.MarketOrderId &&
                    i.ExternalLineId == line.LineNumber).FirstOrDefault();

                var item = existing ?? new MarketOrderItem
                {
                    MarketOrderId = order.MarketOrderId,
                    ExternalLineId = line.LineNumber
                };

                var qty = line.OrderLineQuantity?.Amount ?? 0;
                var unitPrice = line.Charges?.Charge?.ChargeAmount?.Amount;
                var tax = line.Charges?.Charge?.Tax?.Amount;

                item.ExternalSku = line.Item?.Sku;
                item.ExternalItemName = line.Item?.ProductName;
                item.Qty = qty;
                item.UnitPrice = unitPrice;
                item.TaxAmount = tax;
                item.LineTotal = unitPrice.HasValue ? unitPrice.Value * qty : null;
                item.MatchStatus = existing?.MatchStatus ?? "unmatched";
                item.UpdatedAt = existing == null ? item.UpdatedAt : DateTime.UtcNow;

                if (existing == null) Uow.MarketOrderItems.Add(item);
                else Uow.MarketOrderItems.Update(item);
            }

            Uow.Commit();
        }

        private static string ResolveCurrency(WalmartOrder order)
        {
            return order.GetOrderLines()
                .Select(l => l.Charges?.Charge?.ChargeAmount?.Currency)
                .FirstOrDefault(c => !string.IsNullOrWhiteSpace(c))
                ?? "USD";
        }
    }
}
