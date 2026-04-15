using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Contract.Services.Marketplace;
using KLS.Contract.Services.Marketplace.Ebay;
using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.Json;
using System.Threading.Tasks;

namespace KLS.Services.Marketplace.Ebay
{
    public class EbayListingService : BaseService, IMarketplaceListingService
    {
        private readonly IEbayApiClient _client;
        private readonly IMarketSyncLogService _logService;

        public EbayListingService(IUnitOfWork uow, IEbayApiClient client, IMarketSyncLogService logService) : base(uow)
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
                var ok = !string.Equals(result.Status, MarketSyncStatus.Failed.ToValue(), StringComparison.OrdinalIgnoreCase);
                _logService.CompleteLog(syncLog.MarketSyncLogId, ok, 1, ok ? 1 : 0, ok ? 0 : 1);
                return result;
            }
            catch (Exception ex)
            {
                _logService.CompleteLog(syncLog.MarketSyncLogId, false, 1, 0, 1, ex.Message);
                throw;
            }
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
                    var r = await PushListingInternalAsync(map.MarketItemMapId);
                    if (string.Equals(r.Status, MarketSyncStatus.Failed.ToValue(), StringComparison.OrdinalIgnoreCase)) failed++;
                    else succeeded++;
                }
                catch { failed++; }
                await Task.Delay(300);
            }

            _logService.CompleteLog(syncLog.MarketSyncLogId, failed == 0, maps.Count, succeeded, failed);
            return succeeded;
        }

        public async Task RefreshStatusAsync(int marketItemMapId)
        {
            var map = Uow.MarketItemMaps.GetById(marketItemMapId);
            if (map == null || string.IsNullOrWhiteSpace(map.ExternalOfferId)) return;

            try
            {
                var offer = await _client.GetAsync<EbayGetOfferResponse>(
                    map.MarketAccountId,
                    $"/sell/inventory/v1/offer/{Uri.EscapeDataString(map.ExternalOfferId)}");

                if (offer == null) return;

                map.LastSyncAt = DateTime.UtcNow;
                map.LastSyncStatus = MapOfferStatusToSync(offer.status);
                if (!string.IsNullOrWhiteSpace(offer.listingId))
                    map.ExternalListingId = offer.listingId;
                map.UpdatedAt = DateTime.UtcNow;
                Uow.MarketItemMaps.Update(map);
                Uow.Commit();
            }
            catch (Exception ex)
            {
                map.LastSyncAt = DateTime.UtcNow;
                map.LastError = ex.Message;
                map.UpdatedAt = DateTime.UtcNow;
                Uow.MarketItemMaps.Update(map);
                Uow.Commit();
            }
        }

        public async Task<ListingResult> DeleteListingAsync(int marketItemMapId)
        {
            var map = Uow.MarketItemMaps.GetById(marketItemMapId)
                ?? throw new Exception("Item mapping not found");
            if (string.IsNullOrWhiteSpace(map.ExternalOfferId))
                throw new Exception("External offer ID is required before withdrawing an eBay listing");

            try
            {
                await _client.PostRawAsync(
                    map.MarketAccountId,
                    $"/sell/inventory/v1/offer/{Uri.EscapeDataString(map.ExternalOfferId)}/withdraw",
                    new { });

                map.MappingStatus = MarketMappingStatus.Inactive.ToValue();
                map.LastSyncAt = DateTime.UtcNow;
                map.LastSyncStatus = MarketSyncStatus.Success.ToValue();
                map.LastError = null;
                map.UpdatedAt = DateTime.UtcNow;
                Uow.MarketItemMaps.Update(map);
                Uow.Commit();

                return new ListingResult
                {
                    Sku = map.ExternalSku,
                    Status = MarketSyncStatus.Success.ToValue(),
                    SubmissionId = map.ExternalListingId
                };
            }
            catch (Exception ex)
            {
                map.LastSyncAt = DateTime.UtcNow;
                map.LastSyncStatus = MarketSyncStatus.Failed.ToValue();
                map.LastError = ex.Message;
                map.UpdatedAt = DateTime.UtcNow;
                Uow.MarketItemMaps.Update(map);
                Uow.Commit();
                throw;
            }
        }

        private async Task<ListingResult> PushListingInternalAsync(int marketItemMapId)
        {
            var map = Uow.MarketItemMaps.GetById(marketItemMapId)
                ?? throw new Exception("Item mapping not found");
            var account = Uow.MarketAccounts.GetById(map.MarketAccountId)
                ?? throw new Exception("Market account not found");
            var settings = EbaySettings.FromEncrypted(account.SettingsJson);
            var item = Uow.Items.GetById(map.ItemId)
                ?? throw new Exception("ERP Item not found");
            var itemUnit = ResolveItemUnit(map);

            var issues = ValidateListing(map, item, itemUnit, settings);
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

            var sku = map.ExternalSku!;
            var qty = (int)Math.Max(0, item.LCloseQty ?? 0);
            var price = itemUnit.P1 ?? 0;
            var currency = settings.CurrencyCode ?? "USD";

            // ---------- Step 1: Upsert inventory item ----------
            var inventoryPayload = new EbayInventoryItemRequest
            {
                product = new EbayInventoryProduct
                {
                    title = Truncate(item.ItemName, 80),
                    description = item.ItemName ?? sku
                },
                availability = new EbayInventoryAvailability
                {
                    shipToLocationAvailability = new EbayShipToLocationAvailability { quantity = qty }
                },
                condition = settings.Condition ?? "NEW"
            };

            try
            {
                await _client.PutRawAsync(
                    map.MarketAccountId,
                    $"/sell/inventory/v1/inventory_item/{Uri.EscapeDataString(sku)}",
                    inventoryPayload);
                map.LastSubmissionId = $"inventory_item:{sku}";
            }
            catch (Exception ex)
            {
                return FailMap(map, $"Inventory item upsert failed: {ex.Message}", nullOfferOnFailure: string.IsNullOrEmpty(map.ExternalOfferId));
            }

            // ---------- Step 2: Offer create-or-update ----------
            var categoryId = settings.DefaultCategoryId;
            var offerPayload = new EbayOfferRequest
            {
                sku = sku,
                marketplaceId = settings.MarketplaceId ?? "EBAY_US",
                format = "FIXED_PRICE",
                availableQuantity = qty,
                categoryId = categoryId,
                merchantLocationKey = settings.MerchantLocationKey,
                pricingSummary = new EbayPricingSummary
                {
                    price = new EbayAmount { value = price.ToString("0.00"), currency = currency }
                },
                listingPolicies = new EbayListingPolicies
                {
                    fulfillmentPolicyId = settings.FulfillmentPolicyId,
                    paymentPolicyId = settings.PaymentPolicyId,
                    returnPolicyId = settings.ReturnPolicyId
                }
            };

            string? offerId = map.ExternalOfferId;
            try
            {
                if (string.IsNullOrWhiteSpace(offerId))
                {
                    var created = await _client.PostAsync<EbayOfferResponse>(
                        map.MarketAccountId, "/sell/inventory/v1/offer", offerPayload);
                    offerId = created?.offerId;
                    if (string.IsNullOrWhiteSpace(offerId))
                        throw new Exception("eBay did not return an offerId");
                    map.ExternalOfferId = offerId;
                    map.LastSubmissionId = $"offer:create:{offerId}";
                }
                else
                {
                    await _client.PutRawAsync(
                        map.MarketAccountId,
                        $"/sell/inventory/v1/offer/{Uri.EscapeDataString(offerId)}",
                        offerPayload);
                    map.LastSubmissionId = $"offer:update:{offerId}";
                }

                // Persist offer id immediately per idempotency rule
                map.LastSyncStatus = MarketSyncStatus.Submitted.ToValue();
                map.LastError = null;
                map.UpdatedAt = DateTime.UtcNow;
                Uow.MarketItemMaps.Update(map);
                Uow.Commit();
            }
            catch (Exception ex)
            {
                // Fresh push failure → offerId remains null, mark Failed.
                // Republish failure after step 2 → offerId already set above only if step 2 succeeded,
                // so here it means step 2 actually failed. Never null out good id.
                return FailMap(map, $"Offer upsert failed: {ex.Message}", nullOfferOnFailure: string.IsNullOrEmpty(map.ExternalOfferId));
            }

            // ---------- Step 3: Publish ----------
            try
            {
                var publishRaw = await _client.PostRawAsync(
                    map.MarketAccountId,
                    $"/sell/inventory/v1/offer/{Uri.EscapeDataString(offerId!)}/publish",
                    new { });

                string? listingId = null;
                if (!string.IsNullOrWhiteSpace(publishRaw))
                {
                    try
                    {
                        var publishResp = JsonSerializer.Deserialize<EbayPublishResponse>(
                            publishRaw,
                            new JsonSerializerOptions { PropertyNameCaseInsensitive = true });
                        listingId = publishResp?.listingId;
                    }
                    catch { /* ignore parse issues */ }
                }

                if (!string.IsNullOrWhiteSpace(listingId))
                    map.ExternalListingId = listingId;
                map.ExternalItemName = item.ItemName;
                map.LastSyncStatus = MarketSyncStatus.Success.ToValue();
                map.LastSyncAt = DateTime.UtcNow;
                map.LastError = null;
                map.LastSubmissionId = $"publish:{offerId}";
                map.UpdatedAt = DateTime.UtcNow;
                Uow.MarketItemMaps.Update(map);
                Uow.Commit();

                return new ListingResult
                {
                    Sku = sku,
                    Status = MarketSyncStatus.Success.ToValue(),
                    SubmissionId = map.ExternalListingId ?? offerId
                };
            }
            catch (Exception ex)
            {
                // Offer exists but publish failed → status remains Submitted (not Failed)
                map.LastSyncStatus = MarketSyncStatus.Submitted.ToValue();
                map.LastSyncAt = DateTime.UtcNow;
                map.LastError = $"Publish failed: {ex.Message}";
                map.UpdatedAt = DateTime.UtcNow;
                Uow.MarketItemMaps.Update(map);
                Uow.Commit();

                return new ListingResult
                {
                    Sku = sku,
                    Status = MarketSyncStatus.Submitted.ToValue(),
                    SubmissionId = offerId,
                    Issues = new List<ListingIssue>
                    {
                        new ListingIssue { Code = "PUBLISH_FAILED", Message = ex.Message, Severity = "ERROR" }
                    }
                };
            }
        }

        private ListingResult FailMap(MarketItemMap map, string error, bool nullOfferOnFailure)
        {
            map.LastSyncStatus = MarketSyncStatus.Failed.ToValue();
            map.LastSyncAt = DateTime.UtcNow;
            map.LastError = error;
            map.UpdatedAt = DateTime.UtcNow;
            // Never null out a good offer id — rule per plan §2 idempotency
            if (nullOfferOnFailure) map.ExternalOfferId = null;
            Uow.MarketItemMaps.Update(map);
            Uow.Commit();

            return new ListingResult
            {
                Sku = map.ExternalSku,
                Status = MarketSyncStatus.Failed.ToValue(),
                Issues = new List<ListingIssue>
                {
                    new ListingIssue { Code = "EBAY_API_ERROR", Message = error, Severity = "ERROR" }
                }
            };
        }

        private static string MapOfferStatusToSync(string? offerStatus)
        {
            return (offerStatus ?? "").ToUpperInvariant() switch
            {
                "PUBLISHED" => MarketSyncStatus.Success.ToValue(),
                "UNPUBLISHED" => MarketSyncStatus.Submitted.ToValue(),
                "ENDED" => MarketSyncStatus.Submitted.ToValue(),
                _ => MarketSyncStatus.Submitted.ToValue()
            };
        }

        private static List<ListingIssue> ValidateListing(MarketItemMap map, Item item, ItemUnit itemUnit, EbaySettings settings)
        {
            var issues = new List<ListingIssue>();
            void Add(string code, string msg) => issues.Add(new ListingIssue { Code = code, Message = msg, Severity = "ERROR" });

            if (string.IsNullOrWhiteSpace(map.ExternalSku))
                Add("SKU_REQUIRED", "External SKU is required for eBay listing");
            if (string.IsNullOrWhiteSpace(item.ItemName))
                Add("ITEM_NAME_REQUIRED", "ERP item name is required for eBay listing");
            if ((itemUnit.P1 ?? 0) <= 0)
                Add("PRICE_REQUIRED", "A positive ERP price is required before publishing to eBay");
            if (string.IsNullOrWhiteSpace(settings.FulfillmentPolicyId))
                Add("FULFILLMENT_POLICY_REQUIRED", "Account FulfillmentPolicyId is not configured");
            if (string.IsNullOrWhiteSpace(settings.PaymentPolicyId))
                Add("PAYMENT_POLICY_REQUIRED", "Account PaymentPolicyId is not configured");
            if (string.IsNullOrWhiteSpace(settings.ReturnPolicyId))
                Add("RETURN_POLICY_REQUIRED", "Account ReturnPolicyId is not configured");
            if (string.IsNullOrWhiteSpace(settings.MarketplaceId))
                Add("MARKETPLACE_REQUIRED", "Account MarketplaceId is not configured");
            if (string.IsNullOrWhiteSpace(settings.CurrencyCode))
                Add("CURRENCY_REQUIRED", "Account CurrencyCode is not configured");
            if (string.IsNullOrWhiteSpace(settings.Condition))
                Add("CONDITION_REQUIRED", "Account Condition is not configured");
            if (string.IsNullOrWhiteSpace(settings.DefaultCategoryId))
                Add("CATEGORY_REQUIRED", "Account DefaultCategoryId is not configured");
            if (string.IsNullOrWhiteSpace(settings.MerchantLocationKey))
                Add("MERCHANT_LOCATION_REQUIRED", "Account MerchantLocationKey is not configured");

            return issues;
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

        private static string? Truncate(string? s, int max)
        {
            if (string.IsNullOrEmpty(s)) return s;
            return s!.Length <= max ? s : s.Substring(0, max);
        }
    }
}
