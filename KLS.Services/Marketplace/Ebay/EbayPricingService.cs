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
    public class EbayPricingService : BaseService, IMarketplacePricingService
    {
        private readonly IEbayApiClient _client;
        private readonly IMarketSyncLogService _logService;

        public EbayPricingService(IUnitOfWork uow, IEbayApiClient client, IMarketSyncLogService logService) : base(uow)
        {
            _client = client;
            _logService = logService;
        }

        public async Task<ListingResult> PushPriceAsync(int marketItemMapId)
        {
            var map = Uow.MarketItemMaps.GetById(marketItemMapId)
                ?? throw new Exception("Item mapping not found");

            if (string.IsNullOrWhiteSpace(map.ExternalOfferId))
            {
                map.LastPriceSyncAt = DateTime.UtcNow;
                map.LastPriceSyncStatus = MarketSyncStatus.Submitted.ToValue();
                map.LastError = "Skipped: no eBay offer exists (NotListed)";
                map.UpdatedAt = DateTime.UtcNow;
                Uow.MarketItemMaps.Update(map);
                Uow.Commit();
                return new ListingResult { Sku = map.ExternalSku, Status = "skipped-notlisted" };
            }

            if (map.MappingStatus.Is(MarketMappingStatus.Inactive))
            {
                return new ListingResult { Sku = map.ExternalSku, Status = "skipped-ended" };
            }
            if (map.LastSyncStatus.Is(MarketSyncStatus.Failed))
            {
                return new ListingResult { Sku = map.ExternalSku, Status = "skipped-failed" };
            }

            var account = Uow.MarketAccounts.GetById(map.MarketAccountId)
                ?? throw new Exception("Market account not found");
            var settings = EbaySettings.FromEncrypted(account.SettingsJson);
            var itemUnit = ResolveItemUnit(map);

            var payload = new EbayOfferPriceUpdateRequest
            {
                pricingSummary = new EbayPricingSummary
                {
                    price = new EbayAmount
                    {
                        value = (itemUnit.P1 ?? 0).ToString("0.00"),
                        currency = settings.CurrencyCode ?? "USD"
                    }
                }
            };

            try
            {
                await _client.PutRawAsync(
                    map.MarketAccountId,
                    $"/sell/inventory/v1/offer/{Uri.EscapeDataString(map.ExternalOfferId)}",
                    payload);

                map.LastPriceSyncAt = DateTime.UtcNow;
                map.LastPriceSyncStatus = MarketSyncStatus.Success.ToValue();
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
            int succeeded = 0, failed = 0, skipped = 0;

            foreach (var map in maps)
            {
                try
                {
                    var r = await PushPriceAsync(map.MarketItemMapId);
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

        private ItemUnit ResolveItemUnit(MarketItemMap map)
        {
            if (map.ItemUnitId.HasValue)
            {
                var mapped = Uow.ItemUnits.GetById(map.ItemUnitId.Value);
                if (mapped != null) return mapped;
            }
            return Uow.ItemUnits.Find(u => u.ItemId == map.ItemId && u.IsBaseUnit).FirstOrDefault()
                ?? throw new Exception("Base unit not found for item");
        }
    }
}
