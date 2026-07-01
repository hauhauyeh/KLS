using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Contract.Services.Marketplace;
using KLS.Contract.Services.Marketplace.ShipStation;
using KLS.Models;
using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Linq;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;

namespace KLS.Services.Marketplace.ShipStation
{
    public class ShipStationOrderService : BaseService, IMarketplaceOrderService
    {
        private readonly IShipStationApiClient _client;
        private readonly IMarketSyncLogService _logService;

        private const int PageSize = 500;

        // Per-account in-process concurrency guard: one pull at a time per MarketAccountId.
        private static readonly ConcurrentDictionary<int, SemaphoreSlim> _pullGuards = new();

        public ShipStationOrderService(IUnitOfWork uow, IShipStationApiClient client, IMarketSyncLogService logService) : base(uow)
        {
            _client = client;
            _logService = logService;
        }

        public async Task<int> PullOrdersAsync(int marketAccountId, DateTime? since = null)
        {
            var guard = _pullGuards.GetOrAdd(marketAccountId, _ => new SemaphoreSlim(1, 1));
            if (!await guard.WaitAsync(0))
            {
                var skipLog = _logService.StartLog(marketAccountId, "order-pull");
                _logService.CompleteLog(skipLog.MarketSyncLogId, true, 0, 0, 0, "skipped: pull already in progress");
                return 0;
            }

            var syncLog = _logService.StartLog(marketAccountId, "order-pull");
            int inserted = 0, updated = 0, failed = 0, pages = 0;

            try
            {
                var account = Uow.MarketAccounts.GetById(marketAccountId)
                    ?? throw new InvalidOperationException("Market account not found");
                var settings = ShipStationSettings.FromEncrypted(account.SettingsJson);

                DateTime? modifyDateStart = null;
                DateTime? createDateStart = null;
                if (account.LastSyncAt == null)
                {
                    createDateStart = since ?? DateTime.UtcNow.AddDays(-4);
                }
                else
                {
                    var baseFrom = since ?? account.LastSyncAt.Value;
                    modifyDateStart = baseFrom.AddMinutes(-10);
                }

                DateTime? maxModifyUtc = account.LastSyncAt;

                int page = 1;
                int totalPages = 1;
                do
                {
                    var response = await _client.GetOrdersAsync(
                        marketAccountId, page, PageSize,
                        modifyDateStart, createDateStart, settings.StoreId, CancellationToken.None);

                    if (response?.orders == null || response.orders.Count == 0) break;
                    totalPages = response.pages > 0 ? response.pages : 1;
                    pages++;

                    foreach (var order in response.orders)
                    {
                        try
                        {
                            var isNew = UpsertOrder(marketAccountId, order);
                            if (isNew) inserted++; else updated++;
                            if (order.modifyDate.HasValue)
                            {
                                var utc = ShipStationApiClient.PacificToUtc(order.modifyDate.Value);
                                if (!maxModifyUtc.HasValue || utc > maxModifyUtc.Value)
                                    maxModifyUtc = utc;
                            }
                        }
                        catch
                        {
                            failed++;
                        }
                    }

                    page++;
                } while (page <= totalPages);

                // Advance watermark from max remote modifyDate actually processed
                if ((inserted + updated) > 0 && maxModifyUtc.HasValue)
                {
                    account.LastSyncAt = maxModifyUtc.Value;
                }
                account.LastSyncStatus = failed == 0 ? "success" : "failed";
                account.LastError = failed == 0 ? null : $"{failed} order(s) failed during pull";
                account.UpdatedAt = DateTime.UtcNow;
                Uow.MarketAccounts.Update(account);
                Uow.Commit();

                var total = inserted + updated + failed;
                _logService.CompleteLog(syncLog.MarketSyncLogId, failed == 0, total, inserted + updated, failed,
                    failed == 0 ? null : $"{failed} failures");
                return inserted + updated;
            }
            catch (Exception ex)
            {
                var total = inserted + updated + failed;
                _logService.CompleteLog(syncLog.MarketSyncLogId, false, total, inserted + updated, failed, ex.Message);
                throw;
            }
            finally
            {
                guard.Release();
            }
        }

        private bool UpsertOrder(int marketAccountId, ShipStationOrder src)
        {
            var externalOrderId = src.orderId.ToString();
            var existing = Uow.MarketOrders.Find(o =>
                o.MarketAccountId == marketAccountId &&
                o.ExternalOrderId == externalOrderId).FirstOrDefault();

            var isNew = existing == null;
            var order = existing ?? new MarketOrder
            {
                MarketAccountId = marketAccountId,
                ExternalOrderId = externalOrderId
            };

            // Header fields (refresh on every pull; preserve ERP fields + PK + CreatedAt)
            order.ExternalOrderNo = !string.IsNullOrWhiteSpace(src.orderNumber) ? src.orderNumber : src.orderKey;
            order.ExternalCustomerId = src.customerId?.ToString();
            order.OrderDate = src.orderDate.HasValue ? ShipStationApiClient.PacificToUtc(src.orderDate.Value) : (DateTime?)null;
            order.OrderStatus = src.orderStatus ?? MarketInternalOrderStatus.Pending.ToValue();
            order.CustomerName = src.customerUsername;
            order.CustomerEmail = string.IsNullOrWhiteSpace(src.customerEmail) ? null : src.customerEmail;
            order.Phone = src.shipTo?.phone;
            order.ShipToName = src.shipTo?.name;
            order.ShipToCompany = src.shipTo?.company;
            order.ShipToAddress1 = src.shipTo?.street1;
            order.ShipToAddress2 = src.shipTo?.street2;
            order.ShipToCity = src.shipTo?.city;
            order.ShipToState = src.shipTo?.state;
            order.ShipToPostalCode = src.shipTo?.postalCode;
            order.ShipToCountry = src.shipTo?.country;
            order.OrderTotal = src.orderTotal;
            order.ShippingAmount = src.shippingAmount;
            order.TaxAmount = src.taxAmount;
            order.SalesChannel = !string.IsNullOrWhiteSpace(src.advancedOptions?.source) ? src.advancedOptions.source : "ShipStation";
            order.RawJson = JsonSerializer.Serialize(src);
            order.LastSyncAt = DateTime.UtcNow;
            order.LastSyncStatus = MarketSyncStatus.Success.ToValue();
            order.LastError = null;
            if (!isNew) order.UpdatedAt = DateTime.UtcNow;

            if (isNew) Uow.MarketOrders.Add(order);
            else Uow.MarketOrders.Update(order);
            Uow.Commit();

            ReplaceOrderItems(order, src);

            return isNew;
        }

        private void ReplaceOrderItems(MarketOrder order, ShipStationOrder src)
        {
            // Capture match state from existing lines before delete (keyed by ExternalLineId)
            var existingLines = Uow.MarketOrderItems.Find(i => i.MarketOrderId == order.MarketOrderId).ToList();
            var matchState = new Dictionary<string, (string MatchStatus, int? ItemId, int? ItemUnitId, int? MarketItemMapId)>();
            foreach (var e in existingLines)
            {
                if (!string.IsNullOrWhiteSpace(e.ExternalLineId)
                    && !string.Equals(e.MatchStatus, "unmatched", StringComparison.OrdinalIgnoreCase))
                {
                    matchState[e.ExternalLineId] = (e.MatchStatus, e.ItemId, e.ItemUnitId, e.MarketItemMapId);
                }
                Uow.MarketOrderItems.Remove(e);
            }
            if (existingLines.Count > 0) Uow.Commit();

            if (src.items == null || src.items.Count == 0) return;

            var newItems = new List<MarketOrderItem>();

            foreach (var line in src.items)
            {
                var externalLineId = line.orderItemId.ToString();
                var qty = line.quantity;
                var unitPrice = line.unitPrice;
                var item = new MarketOrderItem
                {
                    MarketOrderId = order.MarketOrderId,
                    ExternalLineId = externalLineId,
                    ExternalSku = string.IsNullOrWhiteSpace(line.sku) ? null : line.sku,
                    ExternalUpc = string.IsNullOrWhiteSpace(line.upc) ? null : line.upc.Trim(),
                    ExternalListingId = line.productId?.ToString(),
                    ExternalItemName = line.name,
                    Qty = qty,
                    UnitPrice = unitPrice,
                    TaxAmount = line.taxAmount,
                    LineTotal = unitPrice.HasValue ? unitPrice.Value * qty : (decimal?)null,
                    MatchStatus = "unmatched"
                };

                if (matchState.TryGetValue(externalLineId, out var prior))
                {
                    item.MatchStatus = prior.MatchStatus;
                    item.ItemId = prior.ItemId;
                    item.ItemUnitId = prior.ItemUnitId;
                    item.MarketItemMapId = prior.MarketItemMapId;
                }
                else
                {
                    newItems.Add(item);
                }

                Uow.MarketOrderItems.Add(item);
            }

            Uow.Commit();

            // Calculate Subtotal from item line totals
            order.Subtotal = src.items.Sum(l => l.unitPrice.HasValue ? l.unitPrice.Value * l.quantity : 0m);
            Uow.MarketOrders.Update(order);
            Uow.Commit();

            // Auto-match new items by SKU map then UPC/barcode fallback
            if (newItems.Count > 0)
            {
                AutoMatchItems(order.MarketAccountId, newItems);
            }
        }
        private void AutoMatchItems(int marketAccountId, List<MarketOrderItem> items)
        {
            bool changed = false;
            foreach (var item in items)
            {
                // 1) Try MarketItemMap by SKU
                MarketItemMap? map = null;
                if (!string.IsNullOrEmpty(item.ExternalSku))
                {
                    map = Uow.MarketItemMaps.Find(m =>
                        m.MarketAccountId == marketAccountId &&
                        m.ExternalSku == item.ExternalSku).FirstOrDefault();
                }

                if (map != null)
                {
                    item.ItemId = map.ItemId;
                    item.ItemUnitId = map.ItemUnitId;
                    item.MarketItemMapId = map.MarketItemMapId;
                    item.MatchStatus = "matched";
                    Uow.MarketOrderItems.Update(item);
                    changed = true;
                }
                // 2) Fallback: match ExternalUpc against ItemUnit.Barcode
                else if (!string.IsNullOrEmpty(item.ExternalUpc))
                {
                    var upcTrimmed = item.ExternalUpc.Trim();
                    var unitMatch = Uow.ItemUnits.Find(u =>
                        u.Barcode == upcTrimmed).FirstOrDefault();

                    if (unitMatch != null)
                    {
                        item.ItemId = unitMatch.ItemId;
                        item.ItemUnitId = unitMatch.ItemUnitId;
                        item.MarketItemMapId = null;
                        item.MatchStatus = "matched_upc";
                        Uow.MarketOrderItems.Update(item);
                        changed = true;
                    }
                }
            }
            if (changed) Uow.Commit();
        }
    }
}
