using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Contract.Services.Marketplace;
using KLS.Contract.Services.Marketplace.Ebay;
using KLS.Models;
using System;
using System.Globalization;
using System.Linq;
using System.Text.Json;
using System.Threading.Tasks;

namespace KLS.Services.Marketplace.Ebay
{
    public class EbayOrderService : BaseService, IMarketplaceOrderService
    {
        private readonly IEbayApiClient _client;
        private readonly IMarketSyncLogService _logService;

        private const int PageLimit = 200;

        public EbayOrderService(IUnitOfWork uow, IEbayApiClient client, IMarketSyncLogService logService) : base(uow)
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

            try
            {
                int offset = 0;
                var fromIso = from.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ", CultureInfo.InvariantCulture);
                var filter = Uri.EscapeDataString($"creationdate:[{fromIso}..]");

                while (true)
                {
                    var endpoint = $"/sell/fulfillment/v1/order?filter={filter}&limit={PageLimit}&offset={offset}";
                    var response = await _client.GetAsync<EbayOrdersResponse>(marketAccountId, endpoint);
                    if (response?.orders == null || response.orders.Count == 0) break;

                    foreach (var eOrder in response.orders)
                    {
                        try
                        {
                            if (string.IsNullOrWhiteSpace(eOrder.orderId)) continue;

                            var existing = Uow.MarketOrders.Find(o =>
                                o.MarketAccountId == marketAccountId &&
                                o.ExternalOrderId == eOrder.orderId).FirstOrDefault();

                            var order = existing ?? new MarketOrder
                            {
                                MarketAccountId = marketAccountId,
                                ExternalOrderId = eOrder.orderId!
                            };

                            order.ExternalOrderNo = eOrder.legacyOrderId;
                            order.OrderDate = ParseUtc(eOrder.creationDate);
                            order.OrderStatus = eOrder.orderFulfillmentStatus ?? MarketInternalOrderStatus.Pending.ToValue();

                            var shipTo = eOrder.fulfillmentStartInstructions?.FirstOrDefault()?.shippingStep?.shipTo;
                            order.ShipToName = shipTo?.fullName;
                            order.ShipToCompany = shipTo?.companyName;
                            order.ShipToAddress1 = shipTo?.contactAddress?.addressLine1;
                            order.ShipToAddress2 = shipTo?.contactAddress?.addressLine2;
                            order.ShipToCity = shipTo?.contactAddress?.city;
                            order.ShipToState = shipTo?.contactAddress?.stateOrProvince;
                            order.ShipToPostalCode = shipTo?.contactAddress?.postalCode;
                            order.ShipToCountry = shipTo?.contactAddress?.countryCode;
                            order.Phone = shipTo?.primaryPhone?.phoneNumber;
                            order.CustomerName = shipTo?.fullName ?? eOrder.buyer?.username;
                            order.CustomerEmail = shipTo?.email ?? eOrder.buyer?.buyerRegistrationAddress?.email;
                            order.ExternalCustomerId = eOrder.buyer?.username;

                            order.CurrencyCode = eOrder.pricingSummary?.total?.currency ?? "USD";
                            order.Subtotal = ParseDecimal(eOrder.pricingSummary?.priceSubtotal?.value);
                            order.ShippingAmount = ParseDecimal(eOrder.pricingSummary?.deliveryCost?.value);
                            order.TaxAmount = ParseDecimal(eOrder.pricingSummary?.tax?.value);
                            order.OrderTotal = ParseDecimal(eOrder.pricingSummary?.total?.value);

                            order.RawJson = JsonSerializer.Serialize(eOrder);
                            order.LastSyncAt = DateTime.UtcNow;
                            order.LastSyncStatus = MarketSyncStatus.Success.ToValue();
                            order.LastError = null;
                            order.UpdatedAt = existing == null ? order.UpdatedAt : DateTime.UtcNow;

                            if (existing == null) Uow.MarketOrders.Add(order);
                            else Uow.MarketOrders.Update(order);
                            Uow.Commit();

                            UpsertOrderItems(order, eOrder);
                            importedOrUpdated++;
                        }
                        catch
                        {
                            failed++;
                        }
                    }

                    if (string.IsNullOrWhiteSpace(response.next)) break;
                    offset += PageLimit;
                }

                _logService.CompleteLog(syncLog.MarketSyncLogId, failed == 0,
                    importedOrUpdated + failed, importedOrUpdated, failed);
                return importedOrUpdated;
            }
            catch (Exception ex)
            {
                _logService.CompleteLog(syncLog.MarketSyncLogId, false,
                    importedOrUpdated + failed, importedOrUpdated, failed, ex.Message);
                throw;
            }
        }

        private void UpsertOrderItems(MarketOrder order, EbayOrder eOrder)
        {
            if (eOrder.lineItems == null) return;

            foreach (var line in eOrder.lineItems)
            {
                if (string.IsNullOrWhiteSpace(line.lineItemId)) continue;

                var existing = Uow.MarketOrderItems.Find(i =>
                    i.MarketOrderId == order.MarketOrderId &&
                    i.ExternalLineId == line.lineItemId).FirstOrDefault();

                var item = existing ?? new MarketOrderItem
                {
                    MarketOrderId = order.MarketOrderId,
                    ExternalLineId = line.lineItemId
                };

                var unitPrice = ParseDecimal(line.lineItemCost?.value);
                var tax = line.taxes?.Sum(t => ParseDecimal(t.amount?.value) ?? 0);
                var shipping = ParseDecimal(line.deliveryCost?.shippingCost?.value);

                item.ExternalSku = line.sku;
                item.ExternalListingId = line.legacyItemId;
                item.ExternalItemName = line.title;
                item.Qty = line.quantity;
                item.UnitPrice = unitPrice;
                item.TaxAmount = tax > 0 ? tax : null;
                item.LineTotal = ParseDecimal(line.total?.value) ?? (unitPrice.HasValue ? unitPrice.Value * line.quantity : (decimal?)null);

                var facilitatorCollected = line.taxes?.Any(t =>
                    string.Equals(t.behavior, "REMITTED", StringComparison.OrdinalIgnoreCase)
                    || (t.collectedBy ?? false)) == true;
                if (facilitatorCollected || shipping.HasValue)
                {
                    var notesParts = new System.Collections.Generic.List<string>();
                    if (shipping.HasValue) notesParts.Add($"shipping={shipping.Value:0.00}");
                    if (facilitatorCollected) notesParts.Add("mpf-tax=true");
                    item.Notes = string.Join("; ", notesParts);
                }

                item.MatchStatus = existing?.MatchStatus ?? "unmatched";
                item.UpdatedAt = existing == null ? item.UpdatedAt : DateTime.UtcNow;

                if (existing == null) Uow.MarketOrderItems.Add(item);
                else Uow.MarketOrderItems.Update(item);
            }

            Uow.Commit();
        }

        private static decimal? ParseDecimal(string? s)
        {
            if (string.IsNullOrWhiteSpace(s)) return null;
            return decimal.TryParse(s, NumberStyles.Number, CultureInfo.InvariantCulture, out var v) ? v : (decimal?)null;
        }

        private static DateTime? ParseUtc(string? s)
        {
            if (string.IsNullOrWhiteSpace(s)) return null;
            return DateTime.TryParse(s, CultureInfo.InvariantCulture,
                DateTimeStyles.AssumeUniversal | DateTimeStyles.AdjustToUniversal, out var v) ? v : (DateTime?)null;
        }
    }
}
