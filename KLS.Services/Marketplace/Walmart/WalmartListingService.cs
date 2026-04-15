using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Contract.Services.Marketplace;
using KLS.Contract.Services.Marketplace.Walmart;
using KLS.Common;
using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace KLS.Services.Marketplace.Walmart
{
    public class WalmartListingService : BaseService, IMarketplaceListingService
    {
        private readonly IWalmartApiClient _client;
        private readonly IMarketSyncLogService _logService;

        public WalmartListingService(IUnitOfWork uow, IWalmartApiClient client, IMarketSyncLogService logService) : base(uow)
        {
            _client = client;
            _logService = logService;
        }

        public async Task<ListingResult> PushListingAsync(int marketItemMapId)
        {
            var map = Uow.MarketItemMaps.GetById(marketItemMapId)
                ?? throw new Exception("Item mapping not found");
            var syncLog = _logService.StartLog(map.MarketAccountId, "listing-push");

            try
            {
                var result = await PushListingInternalAsync(marketItemMapId);
                _logService.CompleteLog(syncLog.MarketSyncLogId, true, 1, 1, 0);
                return result;
            }
            catch (Exception ex)
            {
                _logService.CompleteLog(syncLog.MarketSyncLogId, false, 1, 0, 1, ex.Message);
                throw;
            }
        }

        public async Task RefreshStatusAsync(int marketItemMapId)
        {
            var map = Uow.MarketItemMaps.GetById(marketItemMapId);
            if (map == null || string.IsNullOrWhiteSpace(map.ExternalSku)) return;

            var result = await _client.GetAsync<WalmartItemStatusResponse>(
                map.MarketAccountId,
                $"/v3/items/{Uri.EscapeDataString(map.ExternalSku)}");

            if (result == null) return;

            map.ExternalItemName = result.ProductName ?? map.ExternalItemName;
            map.LastSyncAt = DateTime.UtcNow;
            map.LastSyncStatus = string.Equals(result.PublishedStatus, "PUBLISHED", StringComparison.OrdinalIgnoreCase)
                ? MarketSyncStatus.Success.ToValue()
                : HasBlockingIssues(result.Issues) ? MarketSyncStatus.Failed.ToValue() : MarketSyncStatus.Submitted.ToValue();
            map.LastError = result.Issues?.Any() == true
                ? string.Join("; ", result.Issues.Select(i => i.Message))
                : null;
            map.UpdatedAt = DateTime.UtcNow;
            Uow.MarketItemMaps.Update(map);
            Uow.Commit();
        }

        public async Task<ListingResult> DeleteListingAsync(int marketItemMapId)
        {
            var map = Uow.MarketItemMaps.GetById(marketItemMapId)
                ?? throw new Exception("Item mapping not found");
            if (string.IsNullOrWhiteSpace(map.ExternalSku))
                throw new Exception("External SKU is required before deleting a Walmart listing");

            await _client.DeleteAsync(map.MarketAccountId, $"/v3/items/{Uri.EscapeDataString(map.ExternalSku)}");

            map.MappingStatus = MarketMappingStatus.Inactive.ToValue();
            map.LastSyncStatus = MarketSyncStatus.Success.ToValue();
            map.LastSyncAt = DateTime.UtcNow;
            map.LastError = null;
            map.UpdatedAt = DateTime.UtcNow;
            Uow.MarketItemMaps.Update(map);
            Uow.Commit();

            return new ListingResult
            {
                Sku = map.ExternalSku,
                Status = "DELETED"
            };
        }

        public async Task<int> PushAllAsync(int marketAccountId)
        {
            var maps = Uow.MarketItemMaps.Find(m => m.MarketAccountId == marketAccountId && m.IsActive).ToList();
            var syncLog = _logService.StartLog(marketAccountId, "listing-push-batch");
            int succeeded = 0, failed = 0;

            foreach (var map in maps)
            {
                try { await PushListingInternalAsync(map.MarketItemMapId); succeeded++; }
                catch { failed++; }
                await Task.Delay(500);
            }

            _logService.CompleteLog(syncLog.MarketSyncLogId, failed == 0, maps.Count, succeeded, failed);
            return succeeded;
        }

        private async Task<ListingResult> PushListingInternalAsync(int marketItemMapId)
        {
            var map = Uow.MarketItemMaps.GetById(marketItemMapId)
                ?? throw new Exception("Item mapping not found");
            var item = Uow.Items.GetById(map.ItemId)
                ?? throw new Exception("ERP Item not found");
            var itemUnit = ResolveItemUnit(map);
            var issues = ValidateListing(map, item, itemUnit);
            if (issues.Count > 0)
            {
                map.LastSyncStatus = MarketSyncStatus.Failed.ToValue();
                map.LastSyncAt = DateTime.UtcNow;
                map.LastError = string.Join("; ", issues.Select(i => i.Message));
                map.UpdatedAt = DateTime.UtcNow;
                Uow.MarketItemMaps.Update(map);
                Uow.Commit();

                return new ListingResult
                {
                    Sku = map.ExternalSku,
                    Status = MarketSyncStatus.Failed.ToValue(),
                    Issues = issues
                };
            }

            var account = Uow.MarketAccounts.GetById(map.MarketAccountId)
                ?? throw new Exception("Market account not found");
            var settings = WalmartSettings.FromEncrypted(account.SettingsJson);
            var payload = new
            {
                sku = map.ExternalSku,
                productName = item.ItemName,
                shortDescription = item.ItemName,
                price = new
                {
                    amount = itemUnit.P1 ?? 0,
                    currency = settings.CurrencyCode ?? "USD"
                },
                published = true
            };

            try
            {
                var response = await _client.PostAsync<WalmartItemSubmissionResponse>(map.MarketAccountId, "/v3/items", payload);
                map.LastSubmissionId = response?.FeedId ?? response?.ItemId;
                map.ExternalItemName = item.ItemName;
                map.LastSyncAt = DateTime.UtcNow;
                map.LastSyncStatus = string.Equals(response?.Status, "PUBLISHED", StringComparison.OrdinalIgnoreCase)
                    ? MarketSyncStatus.Success.ToValue()
                    : MarketSyncStatus.Submitted.ToValue();
                map.LastError = null;
                map.UpdatedAt = DateTime.UtcNow;
                Uow.MarketItemMaps.Update(map);
                Uow.Commit();

                return new ListingResult
                {
                    Sku = map.ExternalSku,
                    Status = map.LastSyncStatus,
                    SubmissionId = map.LastSubmissionId
                };
            }
            catch (Exception ex)
            {
                map.LastSyncStatus = MarketSyncStatus.Failed.ToValue();
                map.LastSyncAt = DateTime.UtcNow;
                map.LastError = ex.Message;
                map.UpdatedAt = DateTime.UtcNow;
                Uow.MarketItemMaps.Update(map);
                Uow.Commit();
                throw;
            }
        }

        private static bool HasBlockingIssues(List<WalmartItemIssue>? issues)
        {
            return issues?.Any(i => string.Equals(i.Severity, "ERROR", StringComparison.OrdinalIgnoreCase)) == true;
        }

        private List<ListingIssue> ValidateListing(MarketItemMap map, Item item, ItemUnit itemUnit)
        {
            var issues = new List<ListingIssue>();
            if (string.IsNullOrWhiteSpace(map.ExternalSku))
            {
                issues.Add(new ListingIssue
                {
                    Code = "SKU_REQUIRED",
                    Message = "External SKU is required for Walmart listing",
                    Severity = "ERROR"
                });
            }

            if (string.IsNullOrWhiteSpace(item.ItemName))
            {
                issues.Add(new ListingIssue
                {
                    Code = "ITEM_NAME_REQUIRED",
                    Message = "ERP item name is required for Walmart listing",
                    Severity = "ERROR"
                });
            }

            if ((itemUnit.P1 ?? 0) <= 0)
            {
                issues.Add(new ListingIssue
                {
                    Code = "PRICE_REQUIRED",
                    Message = "A positive ERP price is required before publishing to Walmart",
                    Severity = "ERROR"
                });
            }

            return issues;
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
