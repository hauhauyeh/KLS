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
    public class AmazonPricingService : BaseService, IMarketplacePricingService
    {
        private readonly IAmazonSpApiClient _client;
        private readonly IMarketSyncLogService _logService;

        public AmazonPricingService(IUnitOfWork uow, IAmazonSpApiClient client, IMarketSyncLogService logService) : base(uow)
        {
            _client = client;
            _logService = logService;
        }

        public async Task<ListingResult> PushPriceAsync(int marketItemMapId)
        {
            var map = Uow.MarketItemMaps.GetById(marketItemMapId);
            if (map == null) throw new Exception("Item mapping not found");

            var account = Uow.MarketAccounts.GetById(map.MarketAccountId)
                ?? throw new Exception("Market account not found");
            var settings = AmazonSettings.FromEncrypted(account.SettingsJson);

            var itemUnit = Uow.ItemUnits.Find(u => u.ItemId == map.ItemId && u.IsBaseUnit).FirstOrDefault();
            if (itemUnit == null) throw new Exception("Base unit not found for item");

            var endpoint = $"/listings/2021-08-01/items/{settings.SellerId}/{map.ExternalSku}?marketplaceIds={settings.MarketplaceId}";
            var payload = new
            {
                productType = "PRODUCT",
                patches = new[]
                {
                    new
                    {
                        op = "replace",
                        path = "/attributes/purchasable_offer",
                        value = new[]
                        {
                            new
                            {
                                marketplace_id = settings.MarketplaceId,
                                currency = "USD", // US marketplace only for now; future: derive from account/marketplace config
                                our_price = new[] { new { schedule = new[] { new { value_with_tax = itemUnit.P1 } } } }
                            }
                        }
                    }
                }
            };

            var result = await _client.PatchAsync<AmazonListingSubmissionResult>(map.MarketAccountId, endpoint, payload);

            map.LastPriceSyncStatus = result?.Status == "ACCEPTED" ? "success" : "failed";
            map.LastPriceSyncAt = DateTime.UtcNow;
            map.UpdatedAt = DateTime.UtcNow;
            Uow.MarketItemMaps.Update(map);
            Uow.Commit();

            return new ListingResult { Sku = result?.Sku, Status = result?.Status };
        }

        public async Task<int> PushAllPricesAsync(int marketAccountId)
        {
            var maps = Uow.MarketItemMaps.Find(m => m.MarketAccountId == marketAccountId && m.IsActive).ToList();
            var syncLog = _logService.StartLog(marketAccountId, "price-push-batch");
            int succeeded = 0, failed = 0;

            foreach (var map in maps)
            {
                try { await PushPriceAsync(map.MarketItemMapId); succeeded++; }
                catch { failed++; }
                await Task.Delay(500);
            }

            _logService.CompleteLog(syncLog.MarketSyncLogId, failed == 0, maps.Count, succeeded, failed);
            return succeeded;
        }
    }
}
