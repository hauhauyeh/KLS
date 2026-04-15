using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Contract.Services.Marketplace;
using KLS.Contract.Services.Marketplace.Ebay;
using KLS.Models;
using System;
using System.Linq;
using System.Threading.Tasks;

namespace KLS.Services.Marketplace.Ebay
{
    public class EbayInventoryService : BaseService, IMarketplaceInventoryService
    {
        private readonly IEbayApiClient _client;
        private readonly IMarketSyncLogService _logService;

        public EbayInventoryService(IUnitOfWork uow, IEbayApiClient client, IMarketSyncLogService logService) : base(uow)
        {
            _client = client;
            _logService = logService;
        }

        public async Task<ListingResult> PushInventoryAsync(int marketItemMapId)
        {
            var map = Uow.MarketItemMaps.GetById(marketItemMapId)
                ?? throw new Exception("Item mapping not found");

            if (string.IsNullOrWhiteSpace(map.ExternalOfferId))
            {
                map.LastInventorySyncAt = DateTime.UtcNow;
                map.LastInventorySyncStatus = MarketSyncStatus.Submitted.ToValue();
                map.LastError = "Skipped: no eBay offer exists (NotListed)";
                map.UpdatedAt = DateTime.UtcNow;
                Uow.MarketItemMaps.Update(map);
                Uow.Commit();
                return new ListingResult { Sku = map.ExternalSku, Status = "skipped-notlisted" };
            }
            if (string.IsNullOrWhiteSpace(map.ExternalSku))
                throw new Exception("External SKU is required for eBay inventory sync");
            if (map.MappingStatus.Is(MarketMappingStatus.Inactive))
                return new ListingResult { Sku = map.ExternalSku, Status = "skipped-ended" };
            if (map.LastSyncStatus.Is(MarketSyncStatus.Failed))
                return new ListingResult { Sku = map.ExternalSku, Status = "skipped-failed" };

            var item = Uow.Items.GetById(map.ItemId)
                ?? throw new Exception("ERP Item not found");
            var qty = (int)Math.Max(0, item.LCloseQty ?? 0);

            var payload = new EbayInventoryQuantityUpdateRequest
            {
                availability = new EbayInventoryAvailability
                {
                    shipToLocationAvailability = new EbayShipToLocationAvailability { quantity = qty }
                }
            };

            try
            {
                await _client.PutRawAsync(
                    map.MarketAccountId,
                    $"/sell/inventory/v1/inventory_item/{Uri.EscapeDataString(map.ExternalSku)}",
                    payload);

                map.LastInventorySyncAt = DateTime.UtcNow;
                map.LastInventorySyncStatus = MarketSyncStatus.Success.ToValue();
                map.LastError = null;
                map.UpdatedAt = DateTime.UtcNow;
                Uow.MarketItemMaps.Update(map);
                Uow.Commit();

                return new ListingResult
                {
                    Sku = map.ExternalSku,
                    Status = MarketSyncStatus.Success.ToValue(),
                    SubmissionId = map.ExternalOfferId
                };
            }
            catch (Exception ex)
            {
                map.LastInventorySyncAt = DateTime.UtcNow;
                map.LastInventorySyncStatus = MarketSyncStatus.Failed.ToValue();
                map.LastError = ex.Message;
                map.UpdatedAt = DateTime.UtcNow;
                Uow.MarketItemMaps.Update(map);
                Uow.Commit();
                throw;
            }
        }

        public async Task<int> PushAllInventoryAsync(int marketAccountId)
        {
            var maps = Uow.MarketItemMaps.Find(m => m.MarketAccountId == marketAccountId && m.IsActive).ToList();
            var syncLog = _logService.StartLog(marketAccountId, "inventory-push-batch");
            int succeeded = 0, failed = 0, skipped = 0;

            foreach (var map in maps)
            {
                try
                {
                    var r = await PushInventoryAsync(map.MarketItemMapId);
                    if (r.Status != null && r.Status.StartsWith("skipped", StringComparison.OrdinalIgnoreCase)) skipped++;
                    else succeeded++;
                }
                catch { failed++; }
                await Task.Delay(250);
            }

            _logService.CompleteLog(syncLog.MarketSyncLogId, failed == 0, maps.Count, succeeded, failed,
                skipped > 0 ? $"skipped={skipped}" : null);
            return succeeded;
        }
    }
}
