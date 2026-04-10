using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Contract.Services.Marketplace;
using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Text.Json;
using System.Threading.Tasks;

namespace KLS.Services.Marketplace.Amazon
{
    public class AmazonListingService : BaseService, IMarketplaceListingService
    {
        private readonly IAmazonSpApiClient _client;
        private readonly IMarketSyncLogService _logService;

        public AmazonListingService(IUnitOfWork uow, IAmazonSpApiClient client, IMarketSyncLogService logService) : base(uow)
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

        private async Task<ListingResult> PushListingInternalAsync(int marketItemMapId)
        {
            var map = Uow.MarketItemMaps.GetById(marketItemMapId);
            if (map == null) throw new Exception("Item mapping not found");

            var account = Uow.MarketAccounts.GetById(map.MarketAccountId)
                ?? throw new Exception("Market account not found");
            var settings = AmazonSettings.FromEncrypted(account.SettingsJson);
            var item = Uow.Items.GetById(map.ItemId);
            if (item == null) throw new Exception("ERP Item not found");

            try
            {
                var payload = BuildListingPayload(map, item, settings);
                var endpoint = $"/listings/2021-08-01/items/{settings.SellerId}/{map.ExternalSku}?marketplaceIds={settings.MarketplaceId}";

                var apiResult = await _client.PutAsync<AmazonListingSubmissionResult>(map.MarketAccountId, endpoint, payload);

                map.LastSyncStatus = apiResult?.Status == "ACCEPTED" ? "success" : "failed";
                map.ExternalListingId = apiResult?.SubmissionId;
                map.LastSyncAt = DateTime.UtcNow;
                map.LastError = apiResult?.Issues?.Any() == true
                    ? string.Join("; ", apiResult.Issues.Select(i => i.Message)) : null;
                map.UpdatedAt = DateTime.UtcNow;
                Uow.MarketItemMaps.Update(map);
                Uow.Commit();

                return new ListingResult
                {
                    Sku = apiResult?.Sku,
                    Status = apiResult?.Status,
                    SubmissionId = apiResult?.SubmissionId,
                    Issues = apiResult?.Issues?.Select(i => new ListingIssue
                    {
                        Code = i.Code,
                        Message = i.Message,
                        Severity = i.Severity
                    }).ToList()
                };
            }
            catch (Exception ex)
            {
                map.LastSyncStatus = "failed";
                map.LastError = ex.Message;
                map.LastSyncAt = DateTime.UtcNow;
                map.UpdatedAt = DateTime.UtcNow;
                Uow.MarketItemMaps.Update(map);
                Uow.Commit();
                throw;
            }
        }

        public async Task RefreshStatusAsync(int marketItemMapId)
        {
            var map = Uow.MarketItemMaps.GetById(marketItemMapId);
            if (map == null) return;

            var account = Uow.MarketAccounts.GetById(map.MarketAccountId)
                ?? throw new Exception("Market account not found");
            var settings = AmazonSettings.FromEncrypted(account.SettingsJson);

            var endpoint = $"/listings/2021-08-01/items/{settings.SellerId}/{map.ExternalSku}?marketplaceIds={settings.MarketplaceId}&includedData=summaries,issues";
            var result = await _client.GetAsync<AmazonListingStatus>(map.MarketAccountId, endpoint);

            if (result != null)
            {
                map.ExternalItemName = result.Summaries?.FirstOrDefault()?.ItemName;
                map.LastSyncStatus = result.Issues?.Any(i => i.Severity == "ERROR") == true ? "failed" : "success";
                map.LastSyncAt = DateTime.UtcNow;
                map.LastError = result.Issues?.Any() == true
                    ? string.Join("; ", result.Issues.Select(i => i.Message)) : null;
                map.UpdatedAt = DateTime.UtcNow;
                Uow.MarketItemMaps.Update(map);
                Uow.Commit();
            }
        }

        public async Task<ListingResult> DeleteListingAsync(int marketItemMapId)
        {
            var map = Uow.MarketItemMaps.GetById(marketItemMapId);
            if (map == null) throw new Exception("Item mapping not found");

            var account = Uow.MarketAccounts.GetById(map.MarketAccountId)
                ?? throw new Exception("Market account not found");
            var settings = AmazonSettings.FromEncrypted(account.SettingsJson);

            var endpoint = $"/listings/2021-08-01/items/{settings.SellerId}/{map.ExternalSku}?marketplaceIds={settings.MarketplaceId}";
            await _client.DeleteAsync(map.MarketAccountId, endpoint);

            map.MappingStatus = "inactive";
            map.LastSyncStatus = "success";
            map.LastSyncAt = DateTime.UtcNow;
            map.UpdatedAt = DateTime.UtcNow;
            Uow.MarketItemMaps.Update(map);
            Uow.Commit();

            return new ListingResult { Sku = map.ExternalSku, Status = "DELETED" };
        }

        public async Task<int> PushAllAsync(int marketAccountId)
        {
            var maps = Uow.MarketItemMaps.Find(m => m.MarketAccountId == marketAccountId && m.IsActive).ToList();
            var syncLog = _logService.StartLog(marketAccountId, "listing-push-batch");
            int succeeded = 0, failed = 0;

            foreach (var map in maps)
            {
                try
                {
                    await PushListingInternalAsync(map.MarketItemMapId);
                    succeeded++;
                }
                catch { failed++; }
                await Task.Delay(500);
            }

            _logService.CompleteLog(syncLog.MarketSyncLogId, failed == 0, maps.Count, succeeded, failed);
            return succeeded;
        }

        private static object BuildListingPayload(MarketItemMap map, Item item, AmazonSettings settings)
        {
            return new
            {
                productType = "PRODUCT",
                requirements = "LISTING",
                attributes = new
                {
                    condition_type = new[] { new { value = "new_new", marketplace_id = settings.MarketplaceId } },
                    item_name = new[] { new { value = item.ItemName, marketplace_id = settings.MarketplaceId } },
                    merchant_suggested_asin = !string.IsNullOrEmpty(map.ExternalListingId)
                        ? new[] { new { value = map.ExternalListingId, marketplace_id = settings.MarketplaceId } }
                        : null
                }
            };
        }
    }
}
