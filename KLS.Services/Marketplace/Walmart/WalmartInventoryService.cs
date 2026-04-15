using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Contract.Services.Marketplace;
using KLS.Contract.Services.Marketplace.Walmart;
using KLS.Common;
using KLS.Models;
using System;
using System.Linq;
using System.Threading.Tasks;

namespace KLS.Services.Marketplace.Walmart
{
    public class WalmartInventoryService : BaseService, IMarketplaceInventoryService
    {
        private readonly IWalmartApiClient _client;
        private readonly IMarketSyncLogService _logService;

        public WalmartInventoryService(IUnitOfWork uow, IWalmartApiClient client, IMarketSyncLogService logService) : base(uow)
        {
            _client = client;
            _logService = logService;
        }

        public async Task<ListingResult> PushInventoryAsync(int marketItemMapId)
        {
            var map = Uow.MarketItemMaps.GetById(marketItemMapId)
                ?? throw new Exception("Item mapping not found");
            if (string.IsNullOrWhiteSpace(map.ExternalSku))
                throw new Exception("External SKU is required for Walmart inventory sync");

            var item = Uow.Items.GetById(map.ItemId)
                ?? throw new Exception("ERP Item not found");

            var payload = new
            {
                sku = map.ExternalSku,
                quantity = new
                {
                    unit = "EACH",
                    amount = (int)Math.Max(0, item.LCloseQty ?? 0)
                }
            };

            try
            {
                var result = await _client.PutAsync<WalmartInventoryResponse>(
                    map.MarketAccountId,
                    $"/v3/inventory?sku={Uri.EscapeDataString(map.ExternalSku)}",
                    payload);

                map.LastInventorySyncAt = DateTime.UtcNow;
                map.LastInventorySyncStatus = string.Equals(result?.Status, "SUCCESS", StringComparison.OrdinalIgnoreCase)
                    ? MarketSyncStatus.Success.ToValue()
                    : MarketSyncStatus.Submitted.ToValue();
                map.LastError = null;
                map.UpdatedAt = DateTime.UtcNow;
                Uow.MarketItemMaps.Update(map);
                Uow.Commit();

                return new ListingResult
                {
                    Sku = map.ExternalSku,
                    Status = map.LastInventorySyncStatus,
                    SubmissionId = result?.FeedId
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
            int succeeded = 0, failed = 0;

            foreach (var map in maps)
            {
                try { await PushInventoryAsync(map.MarketItemMapId); succeeded++; }
                catch { failed++; }
                await Task.Delay(500);
            }

            _logService.CompleteLog(syncLog.MarketSyncLogId, failed == 0, maps.Count, succeeded, failed);
            return succeeded;
        }
    }
}
