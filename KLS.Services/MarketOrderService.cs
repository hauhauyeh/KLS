using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Contract.Services.Marketplace.ShipStation;
using KLS.Models;
using Microsoft.EntityFrameworkCore;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services
{
    public class MarketOrderService : BaseService, IMarketOrderService
    {
        private readonly IShipStationApiClient _ssClient;

        public MarketOrderService(IUnitOfWork uow, IShipStationApiClient ssClient) : base(uow)
        {
            _ssClient = ssClient;
        }

        public PagingResponse<MarketOrder> GetPagedList(MarketOrderListReq req)
        {
            var list = Uow.MarketOrders.GetPagedList(req).ToList();
            var totalRecords = Uow.MarketOrders.Count(req);
            return new PagingResponse<MarketOrder>(totalRecords, req.Pageno, req.Pagesize)
            {
                RowData = list
            };
        }

        public IEnumerable<MarketOrder> GetByAccount(int marketAccountId)
        {
            return Uow.MarketOrders.Find(o => o.MarketAccountId == marketAccountId)
                .OrderByDescending(o => o.OrderDate).ToList();
        }

        public MarketOrder? GetById(int id)
        {
            return Uow.MarketOrders.Find(o => o.MarketOrderId == id)
                .Include(o => o.Items)
                .FirstOrDefault();
        }

        public MarketOrder? GetByExternalId(int marketAccountId, string externalOrderId)
        {
            return Uow.MarketOrders.Find(o => o.MarketAccountId == marketAccountId && o.ExternalOrderId == externalOrderId).FirstOrDefault();
        }

        public void MatchSkus(int marketOrderId)
        {
            var order = Uow.MarketOrders.GetById(marketOrderId)
                ?? throw new Exception("Market order not found");
            var items = Uow.MarketOrderItems.Find(i => i.MarketOrderId == marketOrderId).ToList();

            foreach (var item in items)
            {
                // 1) Try MarketItemMap by SKU
                MarketItemMap? map = null;
                if (!string.IsNullOrEmpty(item.ExternalSku))
                {
                    map = Uow.MarketItemMaps.Find(m =>
                        m.MarketAccountId == order.MarketAccountId &&
                        m.ExternalSku == item.ExternalSku).FirstOrDefault();
                }

                if (map != null)
                {
                    item.ItemId = map.ItemId;
                    item.ItemUnitId = map.ItemUnitId;
                    item.MarketItemMapId = map.MarketItemMapId;
                    item.MatchStatus = "matched";
                }
                // 2) Fallback: match ExternalUpc against ItemUnit.Barcode
                else if (!string.IsNullOrEmpty(item.ExternalUpc))
                {
                    var unitMatch = Uow.ItemUnits.Find(u =>
                        u.Barcode == item.ExternalUpc).FirstOrDefault();

                    if (unitMatch != null)
                    {
                        item.ItemId = unitMatch.ItemId;
                        item.ItemUnitId = unitMatch.ItemUnitId;
                        item.MarketItemMapId = null;
                        item.MatchStatus = "matched_upc";
                    }
                    else
                    {
                        item.MatchStatus = "unmatched";
                    }
                }
                else
                {
                    item.MatchStatus = "unmatched";
                }
                Uow.MarketOrderItems.Update(item);
            }
            Uow.Commit();
        }

        public async Task LinkOrderItemAsync(int marketOrderItemId, int itemId, int itemUnitId,
            string? barcodeAction = null, string? newBarcode = null)
        {
            var orderItem = Uow.MarketOrderItems.GetById(marketOrderItemId)
                ?? throw new Exception("Market order item not found");
            var order = Uow.MarketOrders.GetById(orderItem.MarketOrderId)
                ?? throw new Exception("Market order not found");

            if (!string.IsNullOrEmpty(orderItem.ExternalSku))
            {
                var map = Uow.MarketItemMaps.Find(m =>
                    m.MarketAccountId == order.MarketAccountId &&
                    m.ExternalSku == orderItem.ExternalSku).FirstOrDefault();

                if (map == null)
                {
                    map = new MarketItemMap
                    {
                        MarketAccountId = order.MarketAccountId,
                        ExternalSku = orderItem.ExternalSku,
                        ExternalItemName = orderItem.ExternalItemName,
                        ItemId = itemId,
                        ItemUnitId = itemUnitId,
                        MappingStatus = "mapped",
                        IsActive = true
                    };
                    Uow.MarketItemMaps.Add(map);
                    Uow.Commit();
                }
                else
                {
                    map.ItemId = itemId;
                    map.ItemUnitId = itemUnitId;
                    map.MappingStatus = "mapped";
                    map.UpdatedAt = DateTime.UtcNow;
                    Uow.MarketItemMaps.Update(map);
                    Uow.Commit();
                }

                orderItem.MarketItemMapId = map.MarketItemMapId;
            }

            orderItem.ItemId = itemId;
            orderItem.ItemUnitId = itemUnitId;
            orderItem.MatchStatus = "matched";
            orderItem.UpdatedAt = DateTime.UtcNow;
            Uow.MarketOrderItems.Update(orderItem);
            Uow.Commit();

            // Barcode sync
            if (string.IsNullOrEmpty(barcodeAction)) return;

            string? barcodeToSet = barcodeAction switch
            {
                "use_shipstation" => orderItem.ExternalUpc,
                "new" => newBarcode?.Trim(),
                "use_system" => Uow.ItemUnits.GetById(itemUnitId)?.Barcode,
                _ => null
            };

            if (string.IsNullOrEmpty(barcodeToSet)) return;

            // Update system DB (for "use_shipstation" and "new")
            if (barcodeAction != "use_system")
            {
                var unit = Uow.ItemUnits.GetById(itemUnitId);
                if (unit != null && unit.Barcode != barcodeToSet)
                {
                    var duplicate = Uow.ItemUnits
                        .Find(u => u.Barcode == barcodeToSet && u.ItemUnitId != itemUnitId)
                        .Any();
                    if (duplicate)
                        throw new InvalidOperationException("Barcode already exists on another unit.");

                    unit.Barcode = barcodeToSet;
                    Uow.ItemUnits.Update(unit);
                    Uow.Commit();
                }
            }

            // Update ShipStation product UPC (for "use_system" and "new")
            if (barcodeAction != "use_shipstation"
                && !string.IsNullOrEmpty(orderItem.ExternalListingId)
                && int.TryParse(orderItem.ExternalListingId, out var ssProductId))
            {
                await _ssClient.UpdateProductUpcAsync(
                    order.MarketAccountId, ssProductId, barcodeToSet);
            }
        }

        public int ConvertToSales(int marketAccountId, DateOnly orderDate)
        {
            return Uow.MarketOrders.ConvertToSales(marketAccountId, orderDate);
        }
    }
}
