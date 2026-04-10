using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Contract.Services.Marketplace;
using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services.Marketplace.Amazon
{
    public class AmazonInventoryService : BaseService, IMarketplaceInventoryService
    {
        private readonly IAmazonSpApiClient _client;
        private readonly IMarketSyncLogService _logService;

        public AmazonInventoryService(IUnitOfWork uow, IAmazonSpApiClient client, IMarketSyncLogService logService) : base(uow)
        {
            _client = client;
            _logService = logService;
        }

        public async Task<ListingResult> PushInventoryAsync(int marketItemMapId)
        {
            var map = Uow.MarketItemMaps.GetById(marketItemMapId);
            if (map == null) throw new Exception("Item mapping not found");

            var account = Uow.MarketAccounts.GetById(map.MarketAccountId)
                ?? throw new Exception("Market account not found");
            var settings = AmazonSettings.FromEncrypted(account.SettingsJson);

            var item = Uow.Items.GetById(map.ItemId);
            if (item == null) throw new Exception("ERP Item not found");

            var endpoint = $"/listings/2021-08-01/items/{settings.SellerId}/{map.ExternalSku}?marketplaceIds={settings.MarketplaceId}";
            var payload = new
            {
                productType = "PRODUCT",
                patches = new[]
                {
                    new
                    {
                        op = "replace",
                        path = "/attributes/fulfillment_availability",
                        value = new[]
                        {
                            new
                            {
                                fulfillment_channel_code = "DEFAULT",
                                quantity = (int)(item.LCloseQty ?? 0)
                            }
                        }
                    }
                }
            };

            var result = await _client.PatchAsync<AmazonListingSubmissionResult>(map.MarketAccountId, endpoint, payload);

            map.LastInventorySyncStatus = result?.Status == "ACCEPTED" ? "success" : "failed";
            map.LastInventorySyncAt = DateTime.UtcNow;
            map.UpdatedAt = DateTime.UtcNow;
            Uow.MarketItemMaps.Update(map);
            Uow.Commit();

            return new ListingResult { Sku = result?.Sku, Status = result?.Status };
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
