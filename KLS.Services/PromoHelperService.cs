using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Models;
using KLS.Models.PromotionEval;
using Microsoft.EntityFrameworkCore;

namespace KLS.Services
{
    // PromoHelperService is the single source of truth for promotion evaluation.
    //
    // Public entry points split into three roles:
    //   read-only       — EvaluateCart (+ request overload), GetActiveItemDiscounts,
    //                     GetAvailablePromotions  (never touch the database)
    //   apply           — ApplyPromotion  (persists discounts + auto-BOGO reward rows)
    //   toggle          — TogglePromotion (per-user opt-in BOGO; owned by admin UI)
    //
    // Phase 2 data model: promo-generated reward rows carry CartLineType=PROMO_REWARD,
    // IsSystemManaged=true, ParentTempSalesId / RootTempSalesId linking them to the
    // qualifying MAIN row, and a TempSalesPromo link row for deterministic toggle-off.
    // The legacy SourceTempSalesId marker is NOT written by new code.
    //
    // See d:\KLS\AI-Development\plan\promo-centralization.md for the full contract.
    public class PromoHelperService : BaseService, IPromoHelperService
    {
        private readonly ICategoryRollupHelper _categoryRollup;

        public PromoHelperService(IUnitOfWork uow, ICategoryRollupHelper categoryRollup) : base(uow)
        {
            _categoryRollup = categoryRollup;
        }


        #region --- Public Entry Points ---

        // Admin-compatible overload (same shape as retired IPromotionEvaluationService.EvaluateCart).
        public PromoEvaluationResult EvaluateCart(PromotionEvalRequest request) =>
            EvaluateCart(request.SalesId, request.PayeeId);

        // Pure read-only preview. Walks the same qualification logic as ApplyPromotion
        // but performs no DB writes. Additionally surfaces the toggle-offer list and
        // existing toggle links so the admin BOGO UI can render without a separate call.
        public PromoEvaluationResult EvaluateCart(int salesId, int payeeId)
        {
            var result = new PromoEvaluationResult();

            if (!IsPromoEligibleCustomer(payeeId))
                return result;

            var paidRows = LoadPaidRows(salesId, payeeId);
            if (!paidRows.Any()) return result;

            result.Subtotal = paidRows.Sum(t => t.ExtTotal ?? 0m);

            var ownListItemIds = GetOwnListItemIds(payeeId);
            var promoRows = ExcludeOwnListRows(paidRows, ownListItemIds);

            var itemCategoryMap = BuildItemCategoryMap(promoRows);
            var nowLocal = GetLocalNow();
            var today = DateOnly.FromDateTime(nowLocal);

            var promotions = LoadActivePromos(today, result.Subtotal);

            // Canonical evaluator flow: window filter, usage caps, exclusivity gate.
            var qualifying = FilterQualifyingPromos(promotions, promoRows, itemCategoryMap, result.Subtotal, nowLocal, payeeId);

            foreach (var promo in qualifying)
            {
                var amount = CalculateDiscountPreview(promo, promoRows, itemCategoryMap, result.Subtotal);
                if (amount <= 0) continue;

                result.TotalDiscount += amount;
                result.AppliedPromotions.Add(new AppliedPromotionDto
                {
                    PromotionId = promo.PromotionId,
                    Name = promo.Name,
                    PromotionType = promo.PromotionType,
                    DiscountAmount = amount
                });

                // For BOGO promos, surface the reward items so the web cart + admin
                // can render them alongside the paid lines.
                if (Enum.TryParse<EnumHelper.PromotionType>(promo.PromotionType, out var ptype) &&
                    (ptype == EnumHelper.PromotionType.BOGO_ITEM_CATEGORY ||
                     ptype == EnumHelper.PromotionType.BOGO_CART))
                {
                    result.FreeItemsAdded.AddRange(PreviewBogoRewardItems(promo, promoRows, itemCategoryMap, result.Subtotal));
                }
            }

            // Toggle offers (opt-in BOGOs) + active toggle links for admin BOGO UI.
            PopulateToggleOffers(result, salesId, payeeId, promotions, nowLocal);

            return result;
        }

        // Catalog-level item-promo lookup. No customer context — browse badges are
        // shown uniformly to every visitor (cart-level eligibility applies at EvaluateCart).
        public Dictionary<int, ItemPromoDiscount> GetActiveItemDiscounts()
        {
            var nowLocal = GetLocalNow();
            var today = DateOnly.FromDateTime(nowLocal);

            var candidates = Uow.Promotions.GetAll()
                .Include(p => p.PromotionSchedules)
                .Include(p => p.PromotionItems)
                .Include(p => p.PromotionCategories)
                .Where(p =>
                    p.IsActive &&
                    (p.PromotionType == nameof(EnumHelper.PromotionType.DISCOUNT_ITEM_FLAT) ||
                     p.PromotionType == nameof(EnumHelper.PromotionType.DISCOUNT_ITEM_PERCENTAGE)) &&
                    (p.StartDate == null || p.StartDate <= today) &&
                    (p.EndDate == null || p.EndDate >= today))
                .AsEnumerable()
                .Where(p => IsPromoValidForSchedule(p, nowLocal))
                .ToList();

            if (!candidates.Any()) return new Dictionary<int, ItemPromoDiscount>();

            // Exclusivity at catalog level: if any candidate is IsExclusive, only the
            // exclusive promos compete (rest are shadowed). Tiebreak by DiscountValue
            // DESC then PromotionId ASC.
            var exclusives = candidates.Where(p => p.IsExclusive).ToList();
            if (exclusives.Any()) candidates = exclusives;

            var categoryItemMap = BuildCategoryItemIndex(candidates);

            var result = new Dictionary<int, ItemPromoDiscount>();

            foreach (var promo in candidates)
            {
                var targetItemIds = new HashSet<int>();

                if (promo.PromotionItems != null)
                {
                    foreach (var pi in promo.PromotionItems.Where(x => x.ItemId.HasValue))
                        targetItemIds.Add(pi.ItemId!.Value);
                }

                if (promo.PromotionCategories != null)
                {
                    foreach (var pc in promo.PromotionCategories.Where(x => x.CategoryId.HasValue))
                    {
                        if (categoryItemMap.TryGetValue(pc.CategoryId!.Value, out var items))
                        {
                            foreach (var itemId in items) targetItemIds.Add(itemId);
                        }
                    }
                }

                var info = new ItemPromoDiscount
                {
                    PromotionId = promo.PromotionId,
                    Name = promo.Name,
                    DisplayName = promo.DisplayName,
                    PromotionType = promo.PromotionType,
                    DiscountValue = promo.DiscountValue,
                    MaxDiscountAmount = promo.MaxDiscountAmount
                };

                foreach (var itemId in targetItemIds)
                {
                    if (!result.TryGetValue(itemId, out var existing))
                    {
                        result[itemId] = info;
                    }
                    else
                    {
                        // Highest DiscountValue wins; PromotionId ASC breaks ties.
                        var existingVal = existing.DiscountValue ?? 0m;
                        var newVal = info.DiscountValue ?? 0m;
                        if (newVal > existingVal ||
                            (newVal == existingVal && info.PromotionId < existing.PromotionId))
                        {
                            result[itemId] = info;
                        }
                    }
                }
            }

            return result;
        }

        public Dictionary<int, string> GetActiveItemOfferBadges()
        {
            var nowLocal = GetLocalNow();
            var today = DateOnly.FromDateTime(nowLocal);

            var candidates = Uow.Promotions.GetAll()
                .Include(p => p.PromotionSchedules)
                .Include(p => p.PromotionItems)
                .Include(p => p.PromotionCategories)
                .Include(p => p.PromotionBogos)
                .Where(p =>
                    p.IsActive &&
                    p.PromotionType == nameof(EnumHelper.PromotionType.BOGO_ITEM_CATEGORY) &&
                    (p.StartDate == null || p.StartDate <= today) &&
                    (p.EndDate == null || p.EndDate >= today))
                .AsEnumerable()
                .Where(p => IsPromoValidForSchedule(p, nowLocal))
                .OrderBy(p => p.PromotionId)
                .ToList();

            if (!candidates.Any()) return new Dictionary<int, string>();

            var categoryItemMap = BuildCategoryItemIndex(candidates);
            var result = new Dictionary<int, string>();

            foreach (var promo in candidates)
            {
                if (promo.PromotionBogos == null || !promo.PromotionBogos.Any()) continue;

                foreach (var rule in promo.PromotionBogos)
                {
                    var label = BuildCatalogBogoBadgeText(promo, rule);
                    if (string.IsNullOrWhiteSpace(label)) continue;

                    foreach (var itemId in ResolveConditionTargetItemIds(rule, categoryItemMap))
                    {
                        if (!result.ContainsKey(itemId))
                        {
                            result[itemId] = label;
                        }
                    }
                }
            }

            return result;
        }

        public List<PromotionSummary> GetAvailablePromotions(int salesId, int payeeId)
        {
            if (!IsPromoEligibleCustomer(payeeId))
                return new List<PromotionSummary>();

            var paidRows = LoadPaidRows(salesId, payeeId);
            if (!paidRows.Any()) return new List<PromotionSummary>();

            var subtotal = paidRows.Sum(t => t.ExtTotal ?? 0m);

            var ownListItemIds = GetOwnListItemIds(payeeId);
            var promoRows = ExcludeOwnListRows(paidRows, ownListItemIds);

            var itemCategoryMap = BuildItemCategoryMap(promoRows);
            var nowLocal = GetLocalNow();
            var today = DateOnly.FromDateTime(nowLocal);

            var promotions = LoadActivePromos(today, subtotal);
            var qualifying = FilterQualifyingPromos(promotions, promoRows, itemCategoryMap, subtotal, nowLocal, payeeId);

            return qualifying
                .Select(promo => new PromotionSummary
                {
                    PromotionId = promo.PromotionId,
                    Name = promo.Name,
                    PromotionType = promo.PromotionType,
                    DiscountValue = promo.DiscountValue
                })
                .ToList();
        }

        public PromotionResult ApplyPromotion(int salesId, int payeeId)
        {
            var result = new PromotionResult();

            if (!IsPromoEligibleCustomer(payeeId))
                return result;

            var paidRows = LoadPaidRows(salesId, payeeId);
            if (!paidRows.Any())
                return result;

            result.Subtotal = paidRows.Sum(t => t.ExtTotal ?? 0m);

            // Reset state from any prior apply. Clear promo reward rows and their
            // links, restore per-row OrgPrice so re-evaluation starts clean.
            ResetPriorAppliedState(salesId, payeeId, paidRows);

            var ownListItemIds = GetOwnListItemIds(payeeId);
            var promoRows = ExcludeOwnListRows(paidRows, ownListItemIds);

            var itemCategoryMap = BuildItemCategoryMap(promoRows);
            var nowLocal = GetLocalNow();
            var today = DateOnly.FromDateTime(nowLocal);

            var promotions = LoadActivePromos(today, result.Subtotal);
            var qualifying = FilterQualifyingPromos(promotions, promoRows, itemCategoryMap, result.Subtotal, nowLocal, payeeId);

            foreach (var promo in qualifying)
            {
                if (!Enum.TryParse<EnumHelper.PromotionType>(promo.PromotionType, out var promoType))
                    continue;

                decimal promoDiscount = 0m;

                switch (promoType)
                {
                    case EnumHelper.PromotionType.DISCOUNT_FLAT:
                        promoDiscount = CalcCartFlat(promo, result.Subtotal);
                        break;

                    case EnumHelper.PromotionType.DISCOUNT_PERCENTAGE:
                        promoDiscount = CalcCartPercentage(promo, result.Subtotal);
                        break;

                    case EnumHelper.PromotionType.DISCOUNT_ITEM_FLAT:
                        promoDiscount = ApplyItemFlatDiscount(promo, promoRows, itemCategoryMap);
                        break;

                    case EnumHelper.PromotionType.DISCOUNT_ITEM_PERCENTAGE:
                        promoDiscount = ApplyItemPercentageDiscount(promo, promoRows, itemCategoryMap);
                        break;

                    case EnumHelper.PromotionType.BOGO_ITEM_CATEGORY:
                    case EnumHelper.PromotionType.BOGO_CART:
                        var bogoRewards = ApplyBogoPromotion(promo, promoRows, itemCategoryMap, result.Subtotal, salesId, payeeId);
                        result.FreeItemsAdded.AddRange(bogoRewards);
                        // BOGO's "discount value" for the applied list mirrors the preview calculator.
                        promoDiscount = CalcBogoTotal(promo, promoRows, itemCategoryMap, result.Subtotal);
                        break;
                }

                // Include the promo in AppliedPromotions if it produced a monetary
                // discount OR injected free/discounted reward items.
                bool isBogoWithRewards = promoType is EnumHelper.PromotionType.BOGO_ITEM_CATEGORY or EnumHelper.PromotionType.BOGO_CART
                    && result.FreeItemsAdded.Any(f => f.ItemId > 0);

                if (promoDiscount > 0 || isBogoWithRewards)
                {
                    result.TotalDiscount += promoDiscount;
                    result.AppliedPromotions.Add(new AppliedPromotionDto
                    {
                        PromotionId = promo.PromotionId,
                        Name = promo.Name,
                        PromotionType = promo.PromotionType,
                        DiscountAmount = promoDiscount
                    });
                }
            }

            Uow.Commit();

            return result;
        }

        public PromoEvaluationResult TogglePromotion(PromoToggleRequest request)
        {
            // Migrated from PromotionEvaluationService. Preserves the exact toggle-on /
            // toggle-off semantics (owner reprice + linked reward row + TempSalesPromo link)
            // so admin UI behavior is unchanged through the DI swap.
            return request.Enable ? ToggleOn(request) : ToggleOff(request);
        }

        #endregion


        #region --- Qualification Flow (filter + exclusivity gate) ---

        // Implements steps 1–3 of the canonical evaluator flow: assume eligibility is
        // already checked (step 1 is at entry points), then drop promos that fail
        // window + schedule + usage cap filters, then apply the exclusivity gate.
        private List<Promotion> FilterQualifyingPromos(
            List<Promotion> candidates,
            List<TempSales> paidRows,
            Dictionary<int, int?> itemCategoryMap,
            decimal subtotal,
            DateTime nowLocal,
            int payeeId)
        {
            // Step 2: schedule + usage cap + type-specific qualification.
            var qualified = candidates
                .Where(p => IsPromoValidForSchedule(p, nowLocal))
                .Where(p => PassesUsageCaps(p, payeeId))
                .Where(p => QualifiesForCart(p, paidRows, itemCategoryMap, subtotal))
                .ToList();

            if (qualified.Count <= 1) return qualified;

            // Step 3: exclusivity gate. If any qualifying promo is exclusive, keep
            // only the single exclusive with the highest CalculateDiscountPreview
            // value (tiebreak by PromotionId ASC). Otherwise stack all non-exclusives.
            var exclusives = qualified.Where(p => p.IsExclusive).ToList();
            if (!exclusives.Any()) return qualified;

            var winner = exclusives
                .Select(p => new
                {
                    Promo = p,
                    Amount = CalculateDiscountPreview(p, paidRows, itemCategoryMap, subtotal)
                })
                .OrderByDescending(x => x.Amount)
                .ThenBy(x => x.Promo.PromotionId)
                .Select(x => x.Promo)
                .First();

            return new List<Promotion> { winner };
        }

        // Promo-type-specific cart qualification — moved out of GetAvailablePromotions
        // so every entry point shares the same rules.
        private bool QualifiesForCart(
            Promotion promo,
            List<TempSales> paidRows,
            Dictionary<int, int?> itemCategoryMap,
            decimal subtotal)
        {
            if (!Enum.TryParse<EnumHelper.PromotionType>(promo.PromotionType, out var promoType))
                return false;

            return promoType switch
            {
                // Cart-level discounts: MinOrderAmount is already gated by LoadActivePromos.
                EnumHelper.PromotionType.DISCOUNT_FLAT or
                EnumHelper.PromotionType.DISCOUNT_PERCENTAGE => true,

                // Item/category discounts: at least one matching cart row.
                EnumHelper.PromotionType.DISCOUNT_ITEM_FLAT or
                EnumHelper.PromotionType.DISCOUNT_ITEM_PERCENTAGE =>
                    FilterPaidRowsByPromo(promo, paidRows, itemCategoryMap).Any(),

                // BOGO: at least one rule must meet its condition.
                EnumHelper.PromotionType.BOGO_ITEM_CATEGORY or
                EnumHelper.PromotionType.BOGO_CART =>
                    promo.PromotionBogos != null &&
                    promo.PromotionBogos.Any(rule =>
                        Enum.TryParse<EnumHelper.ConditionType>(rule.ConditionType, out var ct) &&
                        GetConditionSets(rule, ct, paidRows, itemCategoryMap, subtotal) > 0),

                _ => false
            };
        }

        #endregion


        #region --- Shared Eligibility / Loaders ---

        // Unified customer eligibility gate. Returns false when the customer is missing
        // or has promos disabled. OwnList filtering is handled per-item via
        // GetOwnListItemIds / ExcludeOwnListRows at each entry point.
        private bool IsPromoEligibleCustomer(int payeeId)
        {
            var customer = Uow.Customers.GetById(payeeId);
            if (customer == null) return false;
            if (!customer.IsPromotionEnabled) return false;
            return true;
        }

        public HashSet<int> GetOwnListItemIds(int payeeId)
        {
            var customer = Uow.Customers.GetById(payeeId);
            if (customer == null || !customer.HasOwnList) return new HashSet<int>();

            return Uow.ItemQuotes
                .Find(q => q.PayeeId == payeeId && (q.MarkupPercent.HasValue || q.TargetPrice.Value > 0) && !q.Inactive)
                .Select(q => q.ItemId)
                .ToHashSet();
        }

        private static List<TempSales> ExcludeOwnListRows(List<TempSales> paidRows, HashSet<int> ownListItemIds)
        {
            if (!ownListItemIds.Any()) return paidRows;
            return paidRows
                .Where(r => !r.ItemId.HasValue || !ownListItemIds.Contains(r.ItemId.Value))
                .ToList();
        }

        // Phase 3 placeholder. Single integration point for future per-user / global
        // cap enforcement (MaxUsageGlobal, MaxUsagePerUser, MaxDiscountPerUser,
        // IsFirstOrderOnly). Returns true until PromotionUsage table lands.
        private bool PassesUsageCaps(Promotion promo, int payeeId) => true;

        // "Paid rows" = customer-added MAIN lines (no BOGO reward rows, no soft-deletes).
        // Excludes both legacy SourceTempSalesId!=null rows AND new
        // CartLineType=PROMO_REWARD rows so the purge/migration transition is safe.
        private List<TempSales> LoadPaidRows(int salesId, int payeeId) =>
            Uow.TempSales
                .Find(t => t.SalesId == salesId
                        && t.PayeeId == payeeId
                        && t.SourceTempSalesId == null
                        && t.CartLineType != "PROMO_REWARD"
                        && t.ChangeStatus != EnumHelper.ChangeStatus.D.ToString())
                .ToList();

        private Dictionary<int, int?> BuildItemCategoryMap(List<TempSales> paidRows)
        {
            var itemIds = paidRows
                .Where(t => t.ItemId.HasValue)
                .Select(t => t.ItemId!.Value)
                .ToHashSet();

            if (!itemIds.Any()) return new Dictionary<int, int?>();

            return Uow.Items
                .Find(i => itemIds.Contains(i.ItemId))
                .Select(i => new { i.ItemId, i.CategoryId })
                .ToDictionary(i => i.ItemId, i => i.CategoryId);
        }

        private List<Promotion> LoadActivePromos(DateOnly today, decimal subtotal) =>
            Uow.Promotions.GetAll()
                .Include(p => p.PromotionItems)
                .Include(p => p.PromotionCategories)
                .Include(p => p.PromotionSchedules)
                .Include(p => p.PromotionBogos)
                .Where(p =>
                    p.IsActive &&
                    (p.StartDate == null || p.StartDate <= today) &&
                    (p.EndDate == null || p.EndDate >= today) &&
                    (p.MinOrderAmount == null || subtotal >= p.MinOrderAmount))
                .OrderByDescending(p => p.MinOrderAmount)
                .ToList();

        // Map { promo's CategoryId -> [ItemIds in the entire subtree] } for each
        // category referenced by the candidate promos. Uses ICategoryRollupHelper
        // so a promo targeting parent "Meat" cascades to items under "Beef", "Pork",
        // etc. One query for items (covers the union of all descendant category IDs).
        private Dictionary<int, List<int>> BuildCategoryItemIndex(IEnumerable<Promotion> candidates)
        {
            var promoCategoryIds = candidates
                .SelectMany(p => p.PromotionCategories ?? Enumerable.Empty<PromotionCategory>())
                .Where(pc => pc.CategoryId.HasValue)
                .Select(pc => pc.CategoryId!.Value)
                .ToHashSet();

            if (!promoCategoryIds.Any()) return new Dictionary<int, List<int>>();

            // Expand each promo's target category to its descendant subtree.
            var descendantMap = _categoryRollup.GetDescendantMap();

            var allRelevantCategoryIds = new HashSet<int>();
            foreach (var pid in promoCategoryIds)
            {
                if (descendantMap.TryGetValue(pid, out var descendants))
                {
                    foreach (var d in descendants) allRelevantCategoryIds.Add(d);
                }
                else
                {
                    // Unknown category (e.g., inactive) — at least include itself.
                    allRelevantCategoryIds.Add(pid);
                }
            }

            // Single query pulling every item whose CategoryId falls anywhere in
            // the union of relevant subtrees.
            var items = Uow.Items
                .Find(i => i.CategoryId.HasValue && allRelevantCategoryIds.Contains(i.CategoryId.Value) && !i.Inactive)
                .Select(i => new { i.ItemId, i.CategoryId })
                .AsEnumerable()
                .ToList();

            // Group results back by the ORIGINAL promo category (not the actual
            // item's CategoryId), so callers see a flat "this promo targets these
            // item ids" map.
            var result = new Dictionary<int, List<int>>();
            foreach (var pid in promoCategoryIds)
            {
                var subtree = descendantMap.TryGetValue(pid, out var d)
                    ? new HashSet<int>(d)
                    : new HashSet<int> { pid };

                result[pid] = items
                    .Where(i => i.CategoryId.HasValue && subtree.Contains(i.CategoryId.Value))
                    .Select(i => i.ItemId)
                    .ToList();
            }

            return result;
        }

        private IEnumerable<int> ResolveConditionTargetItemIds(
            PromotionBogo rule,
            Dictionary<int, List<int>> categoryItemMap)
        {
            if (string.Equals(rule.ConditionType, nameof(EnumHelper.ConditionType.ITEM), StringComparison.OrdinalIgnoreCase) &&
                rule.ConditionItemId.HasValue)
            {
                yield return rule.ConditionItemId.Value;
                yield break;
            }

            if (string.Equals(rule.ConditionType, nameof(EnumHelper.ConditionType.CATEGORY), StringComparison.OrdinalIgnoreCase) &&
                rule.ConditionCategoryId.HasValue &&
                categoryItemMap.TryGetValue(rule.ConditionCategoryId.Value, out var itemIds))
            {
                foreach (var itemId in itemIds)
                {
                    yield return itemId;
                }
            }
        }

        private static string? BuildCatalogBogoBadgeText(Promotion promo, PromotionBogo rule)
        {
            if (!string.IsNullOrWhiteSpace(promo.DisplayName))
                return promo.DisplayName;

            var conditionQty = rule.ConditionQty;
            var rewardQty = rule.RewardQty;

            if (conditionQty is not > 0m || rewardQty is not > 0m)
                return string.IsNullOrWhiteSpace(promo.Name) ? null : promo.Name;

            var rewardText = string.Equals(rule.DiscountType, nameof(EnumHelper.DiscountType.FREE), StringComparison.OrdinalIgnoreCase)
                ? "Free"
                : "Offer";

            var conditionText = FormatQtyForBadge(conditionQty.Value);
            var rewardQtyText = FormatQtyForBadge(rewardQty.Value);

            return $"Buy {conditionText} Get {rewardQtyText} {rewardText}";
        }

        private static string FormatQtyForBadge(decimal qty) =>
            decimal.Truncate(qty) == qty ? decimal.Truncate(qty).ToString() : qty.ToString("0.##");

        // Reset any state left by a prior ApplyPromotion on the same cart. Removes
        // both legacy-marker rows (SourceTempSalesId) and new-shape rows
        // (CartLineType=PROMO_REWARD) so the apply is idempotent across migrations,
        // then restores owner prices from OrgPrice and drops TempSalesPromo links.
        private void ResetPriorAppliedState(int salesId, int payeeId, List<TempSales> paidRows)
        {
            // Capture reward-row IDs BEFORE deleting them so we can scrub their
            // TempSalesPromo links first (FK_TempSalesPromo_Promo on PromoTempSalesId
            // blocks the TempSales delete otherwise).
            var rewardIds = Uow.TempSales
                .Find(t => t.SalesId == salesId && t.PayeeId == payeeId &&
                           (t.SourceTempSalesId != null || t.CartLineType == "PROMO_REWARD"))
                .Select(t => t.TempSalesId)
                .ToList();

            var paidIds = paidRows.Select(p => p.TempSalesId).ToList();

            // Drop TempSalesPromo rows referencing either side — owner (paid row) or
            // reward (row about to be deleted). Must run before the TempSales delete
            // to clear the FK.
            Uow.TempSalesPromos
                .Find(l => paidIds.Contains(l.OwnerTempSalesId) || rewardIds.Contains(l.PromoTempSalesId))
                .ExecuteDelete();

            // Now it's safe to delete reward rows.
            if (rewardIds.Count > 0)
            {
                Uow.TempSales
                    .Find(t => rewardIds.Contains(t.TempSalesId))
                    .ExecuteDelete();
            }

            // Restore owner prices for any rows discounted in a previous apply or
            // toggle-on. OrgPrice captured the pre-discount price once.
            foreach (var row in paidRows.Where(t => (t.DiscountPercent > 0 || t.OrgPrice != null) && t.OrgPrice > 0))
            {
                row.UnitPrice = row.OrgPrice;
                row.DiscountPercent = 0;
                Uow.TempSales.Update(row);
            }

            Uow.Commit();
        }

        #endregion


        #region --- Schedule Check ---

        private bool IsPromoValidForSchedule(Promotion promo, DateTime nowLocal)
        {
            if (promo.PromotionSchedules == null || !promo.PromotionSchedules.Any())
                return true;

            // Admin/default schedules are created from .NET DayOfWeek
            // (Sun=0..Sat=6). Be tolerant of any legacy Sunday rows stored as 7.
            var dow = (int)nowLocal.DayOfWeek;
            var time = nowLocal.TimeOfDay;

            return promo.PromotionSchedules.Any(s =>
                !s.IsClosed &&
                (s.DayOfWeek == dow || (dow == 0 && s.DayOfWeek == 7)) &&
                (
                    (s.StartTime == null && s.EndTime == null) ||
                    (s.StartTime != null && s.EndTime != null &&
                     time >= s.StartTime && time <= s.EndTime)
                ));
        }

        #endregion


        #region --- Pure Calculator (CalculateDiscountPreview) ---

        // Single source of truth for "what is this promo worth on the current cart?"
        // Called by EvaluateCart (preview), ApplyPromotion (for parity), and the
        // exclusivity gate (to pick the best exclusive).
        //
        // Phase 1 coverage: ALL enum combos except dead DISCOUNT_CART (removed).
        private decimal CalculateDiscountPreview(
            Promotion promo,
            List<TempSales> paidRows,
            Dictionary<int, int?> itemCategoryMap,
            decimal subtotal)
        {
            if (!Enum.TryParse<EnumHelper.PromotionType>(promo.PromotionType, out var promoType))
                return 0m;

            return promoType switch
            {
                EnumHelper.PromotionType.DISCOUNT_FLAT =>
                    CalcCartFlat(promo, subtotal),

                EnumHelper.PromotionType.DISCOUNT_PERCENTAGE =>
                    CalcCartPercentage(promo, subtotal),

                EnumHelper.PromotionType.DISCOUNT_ITEM_FLAT =>
                    CalcItemFlatTotal(promo, paidRows, itemCategoryMap),

                EnumHelper.PromotionType.DISCOUNT_ITEM_PERCENTAGE =>
                    CalcItemPercentageTotal(promo, paidRows, itemCategoryMap),

                EnumHelper.PromotionType.BOGO_ITEM_CATEGORY or
                EnumHelper.PromotionType.BOGO_CART =>
                    CalcBogoTotal(promo, paidRows, itemCategoryMap, subtotal),

                _ => 0m
            };
        }

        #endregion


        #region --- Cart-Level Discount Handlers ---

        private static decimal CalcCartFlat(Promotion promo, decimal subtotal)
        {
            if (promo.DiscountValue == null || promo.DiscountValue <= 0) return 0m;
            return Math.Min(promo.DiscountValue.Value, subtotal);
        }

        private static decimal CalcCartPercentage(Promotion promo, decimal subtotal)
        {
            if (promo.DiscountValue == null || promo.DiscountValue <= 0) return 0m;

            var discount = subtotal * (promo.DiscountValue.Value / 100m);

            if (promo.MaxDiscountAmount.HasValue)
                discount = Math.Min(discount, promo.MaxDiscountAmount.Value);

            return Math.Min(discount, subtotal);
        }

        #endregion


        #region --- Item-Level Discount Handlers ---

        private IEnumerable<TempSales> FilterPaidRowsByPromo(
            Promotion promo,
            List<TempSales> paidRows,
            Dictionary<int, int?> itemCategoryMap)
        {
            var itemIds = promo.PromotionItems?
                .Where(pi => pi.ItemId.HasValue)
                .Select(pi => pi.ItemId!.Value)
                .ToHashSet() ?? new HashSet<int>();

            var catIds = promo.PromotionCategories?
                .Where(pc => pc.CategoryId.HasValue)
                .Select(pc => pc.CategoryId!.Value)
                .ToHashSet() ?? new HashSet<int>();

            if (!itemIds.Any() && !catIds.Any())
                return paidRows.Where(t => t.ItemId.HasValue);

            return paidRows.Where(t =>
                t.ItemId.HasValue &&
                (
                    itemIds.Contains(t.ItemId.Value) ||
                    (catIds.Any() &&
                     itemCategoryMap.TryGetValue(t.ItemId.Value, out var catId) &&
                     catId.HasValue &&
                     catIds.Contains(catId.Value))
                ));
        }

        // Row-level math shared between preview and apply paths.
        private static (decimal NewPrice, decimal RowDiscount) ComputeItemFlatRow(TempSales row, decimal discountValue)
        {
            var orgPrice = (row.OrgPrice > 0 ? row.OrgPrice : null) ?? row.UnitPrice ?? 0m;
            var newPrice = Math.Max(0m, orgPrice - discountValue);
            var rowDiscount = (orgPrice - newPrice) * (row.BillQty ?? 0m);
            return (newPrice, rowDiscount);
        }

        private static (decimal NewPrice, decimal RowDiscount) ComputeItemPercentageRow(TempSales row, decimal discountValue)
        {
            var orgPrice = (row.OrgPrice > 0 ? row.OrgPrice : null) ?? row.UnitPrice ?? 0m;
            var newPrice = Math.Max(0m, orgPrice * (1 - discountValue / 100m));
            var rowDiscount = (orgPrice - newPrice) * (row.BillQty ?? 0m);
            return (newPrice, rowDiscount);
        }

        private decimal CalcItemFlatTotal(
            Promotion promo,
            List<TempSales> paidRows,
            Dictionary<int, int?> itemCategoryMap)
        {
            if (promo.DiscountValue == null || promo.DiscountValue <= 0) return 0m;

            var eligible = FilterPaidRowsByPromo(promo, paidRows, itemCategoryMap).ToList();
            if (!eligible.Any()) return 0m;

            return eligible.Sum(row => ComputeItemFlatRow(row, promo.DiscountValue.Value).RowDiscount);
        }

        private decimal CalcItemPercentageTotal(
            Promotion promo,
            List<TempSales> paidRows,
            Dictionary<int, int?> itemCategoryMap)
        {
            if (promo.DiscountValue == null || promo.DiscountValue <= 0) return 0m;

            var eligible = FilterPaidRowsByPromo(promo, paidRows, itemCategoryMap).ToList();
            if (!eligible.Any()) return 0m;

            var total = eligible.Sum(row => ComputeItemPercentageRow(row, promo.DiscountValue.Value).RowDiscount);

            if (promo.MaxDiscountAmount.HasValue)
                total = Math.Min(total, promo.MaxDiscountAmount.Value);

            return total;
        }

        private decimal ApplyItemFlatDiscount(
            Promotion promo,
            List<TempSales> paidRows,
            Dictionary<int, int?> itemCategoryMap)
        {
            if (promo.DiscountValue == null || promo.DiscountValue <= 0) return 0m;

            var eligible = FilterPaidRowsByPromo(promo, paidRows, itemCategoryMap).ToList();
            if (!eligible.Any()) return 0m;

            decimal totalDiscount = 0m;

            foreach (var row in eligible)
            {
                // Capture pre-discount price once so a second apply doesn't compound.
                // Treat OrgPrice <= 0 as uncaptured (SP may set it to 0 when no customer quote exists).
                if (row.OrgPrice is null || row.OrgPrice <= 0)
                    row.OrgPrice = row.UnitPrice;

                var (newPrice, rowDiscount) = ComputeItemFlatRow(row, promo.DiscountValue.Value);
                var orgPrice = row.OrgPrice ?? 0m;

                row.UnitPrice = newPrice;
                row.DiscountPercent = orgPrice > 0
                    ? Math.Round((1 - newPrice / orgPrice) * 100, 4)
                    : 0;

                Uow.TempSales.Update(row);
                totalDiscount += rowDiscount;
            }

            return totalDiscount;
        }

        private decimal ApplyItemPercentageDiscount(
            Promotion promo,
            List<TempSales> paidRows,
            Dictionary<int, int?> itemCategoryMap)
        {
            if (promo.DiscountValue == null || promo.DiscountValue <= 0) return 0m;

            var eligible = FilterPaidRowsByPromo(promo, paidRows, itemCategoryMap).ToList();
            if (!eligible.Any()) return 0m;

            decimal totalDiscount = 0m;

            foreach (var row in eligible)
            {
                if (row.OrgPrice is null || row.OrgPrice <= 0)
                    row.OrgPrice = row.UnitPrice;

                var (newPrice, rowDiscount) = ComputeItemPercentageRow(row, promo.DiscountValue.Value);

                row.UnitPrice = newPrice;
                // Percentage promos preserve the declared rate on the row for admin display.
                row.DiscountPercent = promo.DiscountValue.Value;

                Uow.TempSales.Update(row);
                totalDiscount += rowDiscount;
            }

            if (promo.MaxDiscountAmount.HasValue)
                totalDiscount = Math.Min(totalDiscount, promo.MaxDiscountAmount.Value);

            return totalDiscount;
        }

        #endregion


        #region --- BOGO Handler ---

        // Pure BOGO valuation (Phase 1 full coverage). Sums, across all qualifying
        // rules, the per-unit discount value × reward qty. Per-unit discount depends
        // on DiscountType:
        //   FREE       — full reward-item base-unit P1
        //   FLAT       — min(DiscountValue, P1)           (customer pays P1 - DiscountValue)
        //   PERCENTAGE — P1 * DiscountValue / 100         (customer pays P1 - that)
        private decimal CalcBogoTotal(
            Promotion promo,
            List<TempSales> paidRows,
            Dictionary<int, int?> itemCategoryMap,
            decimal subtotal)
        {
            if (promo.PromotionBogos == null || !promo.PromotionBogos.Any())
                return 0m;

            int maxRepeats = promo.BogoMaxRewardRepeats > 0 ? promo.BogoMaxRewardRepeats : int.MaxValue;
            decimal total = 0m;

            foreach (var rule in promo.PromotionBogos)
            {
                if (!Enum.TryParse<EnumHelper.ConditionType>(rule.ConditionType, out var conditionType)) continue;
                if (!Enum.TryParse<EnumHelper.RewardType>(rule.RewardType, out var rewardType)) continue;
                if (!Enum.TryParse<EnumHelper.DiscountType>(rule.DiscountType, out var discountType)) continue;
                if ((rule.RewardQty ?? 0) <= 0) continue;

                var resolvedRewardItemId = ResolveRewardItemId(rule, rewardType);
                if (!resolvedRewardItemId.HasValue) continue;

                decimal totalRewardQty = ComputeBogoRewardQty(rule, conditionType, paidRows, itemCategoryMap, subtotal, maxRepeats);
                if (totalRewardQty <= 0) continue;

                var rewardP1 = GetRewardItemBasePrice(resolvedRewardItemId.Value);
                var perUnitDiscount = ComputeBogoPerUnitDiscount(rewardP1, discountType, rule.DiscountValue ?? 0m);

                total += perUnitDiscount * totalRewardQty;
            }

            return total;
        }

        // Mirror of CalcBogoTotal but returns the reward-item list for display.
        // FreeItemSummary is reused to represent any reward (free OR discounted).
        private List<FreeItemSummary> PreviewBogoRewardItems(
            Promotion promo,
            List<TempSales> paidRows,
            Dictionary<int, int?> itemCategoryMap,
            decimal subtotal)
        {
            var list = new List<FreeItemSummary>();
            if (promo.PromotionBogos == null || !promo.PromotionBogos.Any()) return list;

            int maxRepeats = promo.BogoMaxRewardRepeats > 0 ? promo.BogoMaxRewardRepeats : int.MaxValue;

            foreach (var rule in promo.PromotionBogos)
            {
                if (!Enum.TryParse<EnumHelper.ConditionType>(rule.ConditionType, out var conditionType)) continue;
                if (!Enum.TryParse<EnumHelper.RewardType>(rule.RewardType, out var rewardType)) continue;
                if (!Enum.TryParse<EnumHelper.DiscountType>(rule.DiscountType, out _)) continue;
                if ((rule.RewardQty ?? 0) <= 0) continue;

                var resolvedRewardItemId = ResolveRewardItemId(rule, rewardType);
                if (!resolvedRewardItemId.HasValue) continue;

                decimal totalRewardQty = ComputeBogoRewardQty(rule, conditionType, paidRows, itemCategoryMap, subtotal, maxRepeats);
                if (totalRewardQty <= 0) continue;

                list.Add(new FreeItemSummary
                {
                    ItemId = resolvedRewardItemId.Value,
                    Qty = totalRewardQty
                });
            }

            return list;
        }

        // Resolve which specific item a BOGO rule rewards. For CATEGORY reward type,
        // delegates to ResolveCategoryRewardItem (highest-priced active item in category).
        private int? ResolveRewardItemId(PromotionBogo rule, EnumHelper.RewardType rewardType)
        {
            return rewardType switch
            {
                EnumHelper.RewardType.SAME_AS_CONDITION => rule.ConditionItemId,
                EnumHelper.RewardType.ITEM => rule.RewardItemId,
                EnumHelper.RewardType.CATEGORY =>
                    rule.RewardCategoryId.HasValue
                        ? ResolveCategoryRewardItem(rule.RewardCategoryId.Value)
                        : null,
                _ => null
            };
        }

        // RewardType = CATEGORY resolution: pick the highest-priced active item in
        // the category. Rationale: BOGO should feel generous to the customer;
        // cheapest-item reward cheapens the promo. Tiebreaker: ItemId DESC (newest).
        private int? ResolveCategoryRewardItem(int categoryId)
        {
            // Join item + its base-unit P1 so the ordering is driven by the actual
            // sales price, not any non-base unit's price variant.
            var candidate = (
                from item in Uow.Items.Find(i => i.CategoryId == categoryId && !i.Inactive)
                join unit in Uow.ItemUnits.Find(u => u.IsBaseUnit)
                    on item.ItemId equals unit.ItemId
                orderby (unit.P1 ?? 0m) descending, item.ItemId descending
                select new { item.ItemId }
            ).FirstOrDefault();

            return candidate?.ItemId;
        }

        // Per-unit discount value for a BOGO reward row, given the reward item's
        // base-unit P1 and the rule's DiscountType + DiscountValue.
        private static decimal ComputeBogoPerUnitDiscount(decimal rewardP1, EnumHelper.DiscountType discountType, decimal discountValue) =>
            discountType switch
            {
                EnumHelper.DiscountType.FREE => rewardP1,
                EnumHelper.DiscountType.FLAT => Math.Min(rewardP1, Math.Max(0m, discountValue)),
                EnumHelper.DiscountType.PERCENTAGE => rewardP1 * Math.Clamp(discountValue, 0m, 100m) / 100m,
                _ => 0m
            };

        // Effective UnitPrice the customer pays for a BOGO reward row.
        //   FREE       → 0
        //   FLAT       → max(0, P1 - DiscountValue)
        //   PERCENTAGE → max(0, P1 * (1 - DiscountValue/100))
        private static decimal ComputeBogoRewardUnitPrice(decimal rewardP1, EnumHelper.DiscountType discountType, decimal discountValue) =>
            discountType switch
            {
                EnumHelper.DiscountType.FREE => 0m,
                EnumHelper.DiscountType.FLAT => Math.Max(0m, rewardP1 - Math.Max(0m, discountValue)),
                EnumHelper.DiscountType.PERCENTAGE => Math.Max(0m, rewardP1 * (1 - Math.Clamp(discountValue, 0m, 100m) / 100m)),
                _ => rewardP1
            };

        // Total reward-item quantity this rule produces on the current cart.
        //   CART condition = one set globally (reward_qty × sets).
        //   ITEM / CATEGORY = sum per qualifying line, each capped by BogoMaxRewardRepeats.
        private decimal ComputeBogoRewardQty(
            PromotionBogo rule,
            EnumHelper.ConditionType conditionType,
            List<TempSales> paidRows,
            Dictionary<int, int?> itemCategoryMap,
            decimal subtotal,
            int maxRepeats)
        {
            int sets = GetConditionSets(rule, conditionType, paidRows, itemCategoryMap, subtotal);
            if (sets <= 0) return 0m;

            if (conditionType == EnumHelper.ConditionType.CART)
            {
                sets = Math.Min(sets, maxRepeats);
                return sets * (rule.RewardQty ?? 1);
            }

            var qualifyingRows = GetQualifyingRows(rule, conditionType, paidRows, itemCategoryMap);
            decimal totalRewardQty = 0m;

            foreach (var qualRow in qualifyingRows)
            {
                decimal rowQty = qualRow.OrdQty ?? 0;
                if ((rule.ConditionQty ?? 0) <= 0 || rowQty <= 0) continue;

                int rowSets = (int)Math.Floor(rowQty / rule.ConditionQty!.Value);
                rowSets = Math.Min(rowSets, maxRepeats);
                if (rowSets <= 0) continue;

                totalRewardQty += rowSets * (rule.RewardQty ?? 1);
            }

            return totalRewardQty;
        }

        // Reward "worth" uses the base-unit P1 price — matches how item pricing is
        // surfaced elsewhere in the catalog (ItemUnit.P1 on IsBaseUnit=true row).
        private decimal GetRewardItemBasePrice(int itemId)
        {
            return Uow.ItemUnits
                .Find(u => u.ItemId == itemId && u.IsBaseUnit)
                .Select(u => u.P1)
                .FirstOrDefault() ?? 0m;
        }

        private List<FreeItemSummary> ApplyBogoPromotion(
            Promotion promo,
            List<TempSales> paidRows,
            Dictionary<int, int?> itemCategoryMap,
            decimal subtotal,
            int salesId,
            int payeeId)
        {
            var rewardsSummary = new List<FreeItemSummary>();

            if (promo.PromotionBogos == null || !promo.PromotionBogos.Any())
                return rewardsSummary;

            int maxRepeats = promo.BogoMaxRewardRepeats > 0 ? promo.BogoMaxRewardRepeats : int.MaxValue;

            foreach (var rule in promo.PromotionBogos)
            {
                if (!Enum.TryParse<EnumHelper.ConditionType>(rule.ConditionType, out var conditionType)) continue;
                if (!Enum.TryParse<EnumHelper.RewardType>(rule.RewardType, out var rewardType)) continue;
                if (!Enum.TryParse<EnumHelper.DiscountType>(rule.DiscountType, out var discountType)) continue;
                if ((rule.RewardQty ?? 0) <= 0) continue;

                var resolvedRewardItemId = ResolveRewardItemId(rule, rewardType);
                if (!resolvedRewardItemId.HasValue) continue;

                int sets = GetConditionSets(rule, conditionType, paidRows, itemCategoryMap, subtotal);
                if (sets <= 0) continue;
                sets = Math.Min(sets, maxRepeats);

                var rewardP1 = GetRewardItemBasePrice(resolvedRewardItemId.Value);
                var rewardUnitPrice = ComputeBogoRewardUnitPrice(rewardP1, discountType, rule.DiscountValue ?? 0m);
                var isFreeReward = discountType == EnumHelper.DiscountType.FREE;

                if (conditionType == EnumHelper.ConditionType.CART)
                {
                    // CART condition → one global reward line, no paid-row parent.
                    decimal totalRewardQty = sets * (rule.RewardQty ?? 1);
                    InsertBogoRewardRow(
                        salesId, payeeId, resolvedRewardItemId.Value, totalRewardQty,
                        promo, rule, ownerTempSalesId: null,
                        unitPrice: rewardUnitPrice, isFree: isFreeReward);

                    rewardsSummary.Add(new FreeItemSummary { ItemId = resolvedRewardItemId.Value, Qty = totalRewardQty });
                }
                else
                {
                    // ITEM / CATEGORY → one reward line per qualifying paid row.
                    var qualifyingRows = GetQualifyingRows(rule, conditionType, paidRows, itemCategoryMap).ToList();

                    foreach (var qualRow in qualifyingRows)
                    {
                        decimal rowQty = qualRow.OrdQty ?? 0;
                        if ((rule.ConditionQty ?? 0) <= 0 || rowQty <= 0) continue;

                        int rowSets = (int)Math.Floor(rowQty / rule.ConditionQty!.Value);
                        rowSets = Math.Min(rowSets, maxRepeats);
                        if (rowSets <= 0) continue;

                        decimal rowRewardQty = rowSets * (rule.RewardQty ?? 1);
                        InsertBogoRewardRow(
                            salesId, payeeId, resolvedRewardItemId.Value, rowRewardQty,
                            promo, rule, ownerTempSalesId: qualRow.TempSalesId,
                            unitPrice: rewardUnitPrice, isFree: isFreeReward);

                        rewardsSummary.Add(new FreeItemSummary { ItemId = resolvedRewardItemId.Value, Qty = rowRewardQty });
                    }
                }
            }

            return rewardsSummary;
        }

        private int GetConditionSets(
            PromotionBogo rule,
            EnumHelper.ConditionType conditionType,
            List<TempSales> paidRows,
            Dictionary<int, int?> itemCategoryMap,
            decimal subtotal)
        {
            switch (conditionType)
            {
                case EnumHelper.ConditionType.CART:
                    return (rule.ConditionMinAmount.HasValue && subtotal >= rule.ConditionMinAmount.Value) ? 1 : 0;

                case EnumHelper.ConditionType.ITEM:
                    if (!rule.ConditionItemId.HasValue || (rule.ConditionQty ?? 0) <= 0) return 0;
                    var qtyItem = paidRows
                        .Where(t => t.ItemId == rule.ConditionItemId.Value)
                        .Sum(t => t.OrdQty ?? 0);
                    return qtyItem < rule.ConditionQty!.Value ? 0 : (int)Math.Floor(qtyItem / rule.ConditionQty.Value);

                case EnumHelper.ConditionType.CATEGORY:
                    if (!rule.ConditionCategoryId.HasValue || (rule.ConditionQty ?? 0) <= 0) return 0;
                    var qtyCat = paidRows
                        .Where(t => t.ItemId.HasValue &&
                                    itemCategoryMap.TryGetValue(t.ItemId.Value, out var cid) &&
                                    cid == rule.ConditionCategoryId.Value)
                        .Sum(t => t.OrdQty ?? 0);
                    return qtyCat < rule.ConditionQty!.Value ? 0 : (int)Math.Floor(qtyCat / rule.ConditionQty.Value);

                default:
                    return 0;
            }
        }

        private IEnumerable<TempSales> GetQualifyingRows(
            PromotionBogo rule,
            EnumHelper.ConditionType conditionType,
            List<TempSales> paidRows,
            Dictionary<int, int?> itemCategoryMap)
        {
            return conditionType switch
            {
                EnumHelper.ConditionType.ITEM when rule.ConditionItemId.HasValue =>
                    paidRows.Where(t => t.ItemId == rule.ConditionItemId.Value),

                EnumHelper.ConditionType.CATEGORY when rule.ConditionCategoryId.HasValue =>
                    paidRows.Where(t =>
                        t.ItemId.HasValue &&
                        itemCategoryMap.TryGetValue(t.ItemId.Value, out var cid) &&
                        cid == rule.ConditionCategoryId.Value),

                _ => Enumerable.Empty<TempSales>()
            };
        }

        // Insert a BOGO reward line into TempSales using the Phase 2 canonical shape:
        // CartLineType=PROMO_REWARD, IsSystemManaged=true, Parent/Root link to the
        // qualifying MAIN row (null for CART condition), plus a TempSalesPromo link
        // so TogglePromotion can find and remove the reward deterministically.
        private void InsertBogoRewardRow(
            int salesId,
            int payeeId,
            int rewardItemId,
            decimal rewardQty,
            Promotion promo,
            PromotionBogo rule,
            int? ownerTempSalesId,
            decimal unitPrice,
            bool isFree)
        {
            var notes = isFree ? $"FREE - {promo.Name}" : $"{promo.Name} promo price";

            // Reward row copies unit shape from the reward item's base unit so line
            // display matches how catalog/cart renders the product.
            var baseUnit = Uow.ItemUnits.Find(u => u.ItemId == rewardItemId && u.IsBaseUnit).FirstOrDefault();

            var rewardRow = new TempSales
            {
                SalesId = salesId,
                PayeeId = payeeId,
                EmpId = UserContext.EmpId,
                ItemId = rewardItemId,
                LineType = EnumHelper.LineType.I.ToString(),
                CartLineType = "PROMO_REWARD",
                IsSystemManaged = true,
                ParentTempSalesId = ownerTempSalesId,
                RootTempSalesId = ownerTempSalesId
            };

            rewardRow.ApplyEdits(rewardQty, isFree: isFree, isOut: false, isCrcg: false, unitPrice: unitPrice, notes: notes);
            if (baseUnit != null)
            {
                rewardRow.ApplyUnit(baseUnit.Unit ?? string.Empty, baseUnit.ItemUnitId, baseUnit.FactorToBase);
            }

            Uow.TempSales.Add(rewardRow);

            // Commit here so the reward row gets its TempSalesId before we write the
            // link row that points to it (two commits is the same pattern TogglePromotion uses).
            Uow.Commit();

            if (ownerTempSalesId.HasValue)
            {
                Uow.TempSalesPromos.Add(new TempSalesPromo
                {
                    OwnerTempSalesId = ownerTempSalesId.Value,
                    PromoTempSalesId = rewardRow.TempSalesId,
                    PromotionId = promo.PromotionId,
                    PromotionBogoId = rule.PromotionBogoId
                });
            }
        }

        #endregion


        #region --- TogglePromotion (migrated from PromotionEvaluationService) ---

        // Populate AvailablePromotions (opt-in BOGO offers) and ActiveLinks (existing
        // toggle-on records) on the EvaluateCart result. Mirrors the behavior the
        // admin BOGO toggle UI previously consumed from PromotionEvaluationService.
        private void PopulateToggleOffers(
            PromoEvaluationResult result,
            int salesId,
            int payeeId,
            List<Promotion> scheduledPromos,
            DateTime nowLocal)
        {
            // Opt-in BOGO rules = ITEM condition, PromoPrice set, single-item reward.
            // These are the offers admin toggles on per-line; auto-BOGOs are already
            // reflected in AppliedPromotions above.
            var bogoRules = scheduledPromos
                .Where(p => IsPromoValidForSchedule(p, nowLocal))
                .SelectMany(p => (p.PromotionBogos ?? Enumerable.Empty<PromotionBogo>())
                    .Where(b => b.ConditionType == "ITEM"
                        && (b.RewardType == "SAME_AS_CONDITION" || b.RewardType == "ITEM")
                        && b.DiscountType == "FREE"
                        && b.PromoPrice != null)
                    .Select(b => new { Promotion = p, Bogo = b }))
                .ToList();

            if (!bogoRules.Any())
                return;

            var ownListItemIds = GetOwnListItemIds(payeeId);

            var cartItems = Uow.TempSales.Find(t =>
                    t.EmpId == UserContext.EmpId
                    && t.SalesId == salesId
                    && t.PayeeId == payeeId
                    && t.LineType == "I"
                    && t.CartLineType == "MAIN"
                    && t.SalesDetailId == null)
                .ToList();

            if (ownListItemIds.Any())
                cartItems = cartItems
                    .Where(t => !t.ItemId.HasValue || !ownListItemIds.Contains(t.ItemId.Value))
                    .ToList();

            if (!cartItems.Any()) return;

            var cartItemIds = cartItems.Select(c => c.TempSalesId).ToList();
            result.ActiveLinks = Uow.TempSalesPromos
                .Find(l => cartItemIds.Contains(l.OwnerTempSalesId))
                .Select(l => new PromoLink
                {
                    OwnerTempSalesId = l.OwnerTempSalesId,
                    PromoTempSalesId = l.PromoTempSalesId
                })
                .ToArray();

            var offers = new List<PromotionEvalResult>();
            foreach (var rule in bogoRules)
            {
                var matchingItems = cartItems
                    .Where(t => t.ItemId == rule.Bogo.ConditionItemId)
                    .ToList();

                if (!matchingItems.Any()) continue;

                offers.Add(new PromotionEvalResult
                {
                    PromotionId = rule.Promotion.PromotionId,
                    PromotionBogoId = rule.Bogo.PromotionBogoId,
                    DisplayName = rule.Promotion.DisplayName ?? rule.Promotion.Name,
                    ConditionItemId = rule.Bogo.ConditionItemId ?? 0,
                    ConditionQty = rule.Bogo.ConditionQty ?? 0,
                    RewardQty = rule.Bogo.RewardQty ?? 0,
                    PromoPrice = rule.Bogo.PromoPrice,
                    BadgeText = $"Buy {rule.Bogo.ConditionQty:0.##} Get {rule.Bogo.RewardQty:0.##}",
                    MatchingTempSalesIds = matchingItems.Select(t => t.TempSalesId).ToArray()
                });
            }

            result.AvailablePromotions = offers.ToArray();
        }

        private PromoEvaluationResult ToggleOn(PromoToggleRequest request)
        {
            // Preserves exact semantics from PromotionEvaluationService.ToggleOn.
            // Full flow: dedupe, load owner, validate, normalize qty, reprice owner,
            // insert reward line, insert TempSalesPromo link, re-evaluate.

            var existingLink = Uow.TempSalesPromos.Find(l =>
                l.OwnerTempSalesId == request.OwnerTempSalesId
                && l.PromotionBogoId == request.PromotionBogoId).FirstOrDefault();
            if (existingLink != null) return EvaluateCart(request.SalesId, request.PayeeId);

            var owner = Uow.TempSales.GetById(request.OwnerTempSalesId);
            if (owner == null) return EvaluateCart(request.SalesId, request.PayeeId);

            // Only MAIN, non-system-managed, non-injected lines can be toggled.
            if (owner.CartLineType != "MAIN" || owner.IsSystemManaged || owner.SalesDetailId != null)
                return EvaluateCart(request.SalesId, request.PayeeId);

            var bogo = Uow.PromotionBogos.GetById(request.PromotionBogoId);
            if (bogo == null || bogo.PromotionId != request.PromotionId)
                return EvaluateCart(request.SalesId, request.PayeeId);

            var promotion = Uow.Promotions.GetById(bogo.PromotionId);
            if (promotion == null) return EvaluateCart(request.SalesId, request.PayeeId);

            if (owner.ItemId != bogo.ConditionItemId)
                return EvaluateCart(request.SalesId, request.PayeeId);

            // Race-condition guard: reward line might already exist even if the link doesn't.
            var existingReward = Uow.TempSales
                .Find(t => t.ParentTempSalesId == owner.TempSalesId
                    && t.CartLineType == "PROMO_REWARD")
                .FirstOrDefault();
            if (existingReward != null)
                return EvaluateCart(request.SalesId, request.PayeeId);

            var conditionQty = bogo.ConditionQty ?? 1;
            if (conditionQty <= 0) conditionQty = 1;

            // Bump owner qty to at least ConditionQty so the toggle always produces
            // one reward set (admin UX: user wants to trigger the promo).
            if ((owner.OrdQty ?? 0) < conditionQty)
            {
                owner.ApplyEdits(conditionQty, owner.IsFree, owner.IsOut, owner.IsCRCG, owner.UnitPrice, owner.Notes);
            }

            // Capture OrgPrice once so toggle-off can restore it cleanly.
            if (owner.OrgPrice is null || owner.OrgPrice <= 0)
                owner.OrgPrice = owner.UnitPrice;

            owner.UnitPrice = bogo.PromoPrice;
            Uow.TempSales.Update(owner);

            // Determine reward item + unit fields.
            int? rewardItemId;
            string? rewardUnit;
            int? rewardItemUnitId;
            decimal? rewardFactorToBase;

            if (bogo.RewardType == "SAME_AS_CONDITION")
            {
                rewardItemId = owner.ItemId;
                rewardUnit = owner.Unit;
                rewardItemUnitId = owner.ItemUnitId;
                rewardFactorToBase = owner.FactorToBase;
            }
            else // ITEM
            {
                rewardItemId = bogo.RewardItemId;
                var baseUnit = Uow.ItemUnits.Find(u => u.ItemId == rewardItemId && u.IsBaseUnit).FirstOrDefault();
                rewardUnit = baseUnit?.Unit;
                rewardItemUnitId = baseUnit?.ItemUnitId;
                rewardFactorToBase = baseUnit?.FactorToBase ?? 1;
            }

            var ownerQty = owner.OrdQty ?? 0;
            var rewardQtyPerSet = bogo.RewardQty ?? 0;
            var maxRepeats = promotion.BogoMaxRewardRepeats;

            var sets = Math.Floor(ownerQty / conditionQty);
            if (maxRepeats > 0 && sets > maxRepeats) sets = maxRepeats;

            var newRewardQty = sets * rewardQtyPerSet;

            var rewardLine = new TempSales
            {
                EmpId = owner.EmpId,
                SalesId = owner.SalesId,
                PayeeId = owner.PayeeId,
                ItemId = rewardItemId,
                CartLineType = "PROMO_REWARD",
                IsSystemManaged = true,
                ParentTempSalesId = owner.TempSalesId,
                RootTempSalesId = owner.TempSalesId,
                IsTaxable = owner.IsTaxable,
                LineType = "I"
            };
            rewardLine.ApplyEdits(newRewardQty, true, false, false, 0, null);
            rewardLine.ApplyUnit(rewardUnit ?? "", rewardItemUnitId, rewardFactorToBase);
            rewardLine.DisplaySort = owner.LineId ?? 0;

            Uow.TempSales.Add(rewardLine);

            // Commit #1 — persist owner + reward so reward gets a TempSalesId.
            Uow.Commit();

            // Commit #2 — link row needs the reward's TempSalesId.
            Uow.TempSalesPromos.Add(new TempSalesPromo
            {
                OwnerTempSalesId = owner.TempSalesId,
                PromoTempSalesId = rewardLine.TempSalesId,
                PromotionId = bogo.PromotionId,
                PromotionBogoId = bogo.PromotionBogoId
            });
            Uow.Commit();

            return EvaluateCart(request.SalesId, request.PayeeId);
        }

        private PromoEvaluationResult ToggleOff(PromoToggleRequest request)
        {
            var link = Uow.TempSalesPromos.Find(l =>
                l.OwnerTempSalesId == request.OwnerTempSalesId
                && l.PromotionBogoId == request.PromotionBogoId).FirstOrDefault();

            if (link == null) return EvaluateCart(request.SalesId, request.PayeeId);

            // Delete link first (FK ordering: TempSalesPromo → TempSales).
            Uow.TempSalesPromos.Remove(link);
            Uow.Commit();

            Uow.TempSales.Find(t => t.TempSalesId == link.PromoTempSalesId).ExecuteDelete();

            var owner = Uow.TempSales.GetById(request.OwnerTempSalesId);
            if (owner == null)
            {
                Uow.Commit();
                return EvaluateCart(request.SalesId, request.PayeeId);
            }

            if (owner.OrgPrice != null)
            {
                owner.UnitPrice = owner.OrgPrice;
                owner.OrgPrice = null;
            }

            Uow.TempSales.Update(owner);
            Uow.Commit();

            return EvaluateCart(request.SalesId, request.PayeeId);
        }

        #endregion


        #region --- Helpers ---

        // User-local time. Falls back to server local if UserTimezone is unset or invalid.
        // Used by schedule check AND the date-range filter so both share one clock.
        private static DateTime GetLocalNow()
        {
            try
            {
                if (!string.IsNullOrEmpty(UserContext.UserTimezone))
                {
                    var tz = TimeZoneInfo.FindSystemTimeZoneById(UserContext.UserTimezone);
                    return TimeZoneInfo.ConvertTimeFromUtc(DateTime.UtcNow, tz);
                }
            }
            catch { /* fallback to server local */ }

            return DateTime.Now;
        }

        #endregion
    }
}
