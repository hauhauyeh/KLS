using KLS.Contract.Interfaces;
using KLS.Contract.Services.Marketplace;
using KLS.Contract.Services.Marketplace.Walmart;
using KLS.Contract.Services;
using KLS.Common;
using KLS.Models;
using System;
using System.Linq;
using System.Threading.Tasks;

namespace KLS.Services.Marketplace.Walmart
{
    public class WalmartPricingService : BaseService, IMarketplacePricingService
    {
        private readonly IWalmartApiClient _client;
        private readonly IMarketSyncLogService _logService;

        public WalmartPricingService(IUnitOfWork uow, IWalmartApiClient client, IMarketSyncLogService logService) : base(uow)
        {
            _client = client;
            _logService = logService;
        }

        public async Task<ListingResult> PushPriceAsync(int marketItemMapId)
        {
            var map = Uow.MarketItemMaps.GetById(marketItemMapId)
                ?? throw new Exception("Item mapping not found");
            if (string.IsNullOrWhiteSpace(map.ExternalSku))
                throw new Exception("External SKU is required for Walmart price sync");

            var account = Uow.MarketAccounts.GetById(map.MarketAccountId)
                ?? throw new Exception("Market account not found");
            var settings = WalmartSettings.FromEncrypted(account.SettingsJson);
            var itemUnit = ResolveItemUnit(map);

            var payload = new
            {
                sku = map.ExternalSku,
                pricing = new[]
                {
                    new
                    {
                        currentPriceType = "BASE",
                        currentPrice = new
                        {
                            amount = itemUnit.P1 ?? 0,
                            currency = settings.CurrencyCode ?? "USD"
                        }
                    }
                }
            };

            try
            {
                var result = await _client.PutAsync<WalmartPriceResponse>(map.MarketAccountId, "/v3/prices", payload);
                map.LastPriceSyncAt = DateTime.UtcNow;
                map.LastPriceSyncStatus = string.Equals(result?.Status, "SUCCESS", StringComparison.OrdinalIgnoreCase)
                    ? MarketSyncStatus.Success.ToValue()
                    : MarketSyncStatus.Submitted.ToValue();
                map.LastError = null;
                map.UpdatedAt = DateTime.UtcNow;
                Uow.MarketItemMaps.Update(map);
                Uow.Commit();

                return new ListingResult
                {
                    Sku = map.ExternalSku,
                    Status = map.LastPriceSyncStatus,
                    SubmissionId = result?.FeedId
                };
            }
            catch (Exception ex)
            {
                map.LastPriceSyncAt = DateTime.UtcNow;
                map.LastPriceSyncStatus = MarketSyncStatus.Failed.ToValue();
                map.LastError = ex.Message;
                map.UpdatedAt = DateTime.UtcNow;
                Uow.MarketItemMaps.Update(map);
                Uow.Commit();
                throw;
            }
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

        private ItemUnit ResolveItemUnit(MarketItemMap map)
        {
            if (map.ItemUnitId.HasValue)
            {
                var mappedUnit = Uow.ItemUnits.GetById(map.ItemUnitId.Value);
                if (mappedUnit != null) return mappedUnit;
            }

            return Uow.ItemUnits.Find(u => u.ItemId == map.ItemId && u.IsBaseUnit).FirstOrDefault()
                ?? throw new Exception("Base unit not found for item");
        }
    }
}
