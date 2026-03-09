using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Models;
using Microsoft.EntityFrameworkCore;

namespace KLS.Services
{
    public class PromoHelperService : BaseService, IPromoHelperService
    {
        public PromoHelperService(IUnitOfWork uow) : base(uow) { }


        #region --- Public Entry Points ---

        public List<PromotionSummary> GetAvailablePromotions(int salesId, int payeeId)
        {
            var customer = Uow.Customers.Find(c => c.PayeeId == payeeId).FirstOrDefault();
            if (customer == null || !customer.IsPromotionEnabled)
                return new List<PromotionSummary>();

            var paidRows = Uow.TempSales
                .Find(t => t.SalesId == salesId
                        && t.PayeeId == payeeId
                        && t.SourceTempSalesId == null
                        && t.ChangeStatus != EnumHelper.ChangeStatus.D.ToString())
                .ToList();

            if (!paidRows.Any()) return new List<PromotionSummary>();

            var subtotal = paidRows.Sum(t => t.ExtTotal ?? 0m);

            // Build item→category map (needed for item/category condition checks)
            var itemIds = paidRows.Where(t => t.ItemId.HasValue).Select(t => t.ItemId!.Value).ToHashSet();
            var itemCategoryMap = Uow.Items
                .Find(i => itemIds.Contains(i.ItemId))
                .Select(i => new { i.ItemId, i.CategoryId })
                .ToDictionary(i => i.ItemId, i => i.CategoryId);

            var today = DateOnly.FromDateTime(DateTime.Now);
            var nowLocal = GetLocalNow();

            var candidates = Uow.Promotions.GetAll()
                .Include(p => p.PromotionSchedules)
                .Include(p => p.PromotionItems)
                .Include(p => p.PromotionCategories)
                .Include(p => p.PromotionBogos)
                .Where(p =>
                    p.IsActive &&
                    (p.StartDate == null && p.EndDate == null ||
                     p.StartDate <= today && p.EndDate >= today) &&
                    (p.MinOrderAmount == null || subtotal >= p.MinOrderAmount))
                .OrderByDescending(p => p.MinOrderAmount)
                .AsEnumerable()
                .Where(p => IsPromoValidForSchedule(p, nowLocal))
                .ToList();

            var result = new List<PromotionSummary>();

            foreach (var promo in candidates)
            {
                if (!Enum.TryParse<EnumHelper.PromotionType>(promo.PromotionType, out var promoType))
                    continue;

                bool qualifies = promoType switch
                {
                    // Cart-level discounts: MinOrderAmount check already passed above
                    EnumHelper.PromotionType.DISCOUNT_FLAT or
                    EnumHelper.PromotionType.DISCOUNT_PERCENTAGE or
                    EnumHelper.PromotionType.DISCOUNT_CART => true,

                    // Item/category discounts: at least one cart row must match
                    EnumHelper.PromotionType.DISCOUNT_ITEM_FLAT or
                    EnumHelper.PromotionType.DISCOUNT_ITEM_PERCENTAGE =>
                        FilterPaidRowsByPromo(promo, paidRows, itemCategoryMap).Any(),

                    // BOGO: at least one rule must have its condition met by the cart
                    EnumHelper.PromotionType.BOGO_ITEM_CATEGORY or
                    EnumHelper.PromotionType.BOGO_CART =>
                        promo.PromotionBogos != null &&
                        promo.PromotionBogos.Any(rule =>
                            Enum.TryParse<EnumHelper.ConditionType>(rule.ConditionType, out var ct) &&
                            GetConditionSets(rule, ct, paidRows, itemCategoryMap, subtotal) > 0),

                    _ => false
                };

                if (!qualifies) continue;

                result.Add(new PromotionSummary
                {
                    PromotionId = promo.PromotionId,
                    Name = promo.Name,
                    PromotionType = promo.PromotionType,
                    DiscountValue = promo.DiscountValue
                });
            }

            return result;
        }

        public PromotionResult ApplyPromotion(int salesId, int payeeId)
        {
            var result = new PromotionResult();

            // 1. Check customer IsPromotionEnabled
            var customer = Uow.Customers.Find(c => c.PayeeId == payeeId).FirstOrDefault();
            if (customer == null || !customer.IsPromotionEnabled)
                return result;

            // 2. Load paid rows only (no promo-created free rows, no soft-deleted rows)
            var paidRows = Uow.TempSales
                .Find(t => t.SalesId == salesId
                        && t.PayeeId == payeeId
                        && t.SourceTempSalesId == null
                        && t.ChangeStatus != EnumHelper.ChangeStatus.D.ToString())
                .ToList();

            if (!paidRows.Any())
                return result;

            // 3. Compute subtotal
            result.Subtotal = paidRows.Sum(t => t.ExtTotal ?? 0m);

            // 4. Delete ALL previously-created promo free rows (full reset before re-evaluation)
            Uow.TempSales
                .Find(t => t.SalesId == salesId && t.PayeeId == payeeId && t.SourceTempSalesId != null)
                .ExecuteDelete();

            // 5. Reset previously promo-applied item discounts (restore OrgPrice)
            foreach (var row in paidRows.Where(t => t.DiscountPercent > 0 && t.OrgPrice > 0))
            {
                row.UnitPrice = row.OrgPrice;
                row.DiscountPercent = 0;
                Uow.TempSales.Update(row);
            }
            Uow.Commit();

            // 6. Build item→category map for category-based promotions
            var itemIds = paidRows
                .Where(t => t.ItemId.HasValue)
                .Select(t => t.ItemId!.Value)
                .ToHashSet();

            var itemCategoryMap = Uow.Items
                .Find(i => itemIds.Contains(i.ItemId))
                .Select(i => new { i.ItemId, i.CategoryId })
                .ToDictionary(i => i.ItemId, i => i.CategoryId);

            // 7. Load active promotions (eager load all child collections)
            var today = DateOnly.FromDateTime(DateTime.Now);

            var promotions = Uow.Promotions.GetAll()
                .Include(p => p.PromotionItems)
                .Include(p => p.PromotionCategories)
                .Include(p => p.PromotionSchedules)
                .Include(p => p.PromotionBogos)
                .Where(p =>
                    p.IsActive &&
                    (p.StartDate == null && p.EndDate == null ||
                     p.StartDate <= today && p.EndDate >= today) &&
                    (p.MinOrderAmount == null || result.Subtotal >= p.MinOrderAmount))
                .OrderByDescending(p => p.MinOrderAmount)
                .ToList();

            // 8. Evaluate each promotion
            var nowLocal = GetLocalNow();

            foreach (var promo in promotions)
            {
                if (!IsPromoValidForSchedule(promo, nowLocal))
                    continue;

                if (!Enum.TryParse<EnumHelper.PromotionType>(promo.PromotionType, out var promoType))
                    continue;

                decimal promoDiscount = 0m;

                switch (promoType)
                {
                    case EnumHelper.PromotionType.DISCOUNT_FLAT:
                        promoDiscount = ApplyDiscountFlat(promo, result.Subtotal);
                        break;

                    case EnumHelper.PromotionType.DISCOUNT_PERCENTAGE:
                        promoDiscount = ApplyDiscountPercentage(promo, result.Subtotal);
                        break;

                    case EnumHelper.PromotionType.DISCOUNT_CART:
                        // Stubbed — implement later
                        break;

                    case EnumHelper.PromotionType.DISCOUNT_ITEM_FLAT:
                        promoDiscount = ApplyItemFlatDiscount(promo, paidRows, itemCategoryMap);
                        break;

                    case EnumHelper.PromotionType.DISCOUNT_ITEM_PERCENTAGE:
                        promoDiscount = ApplyItemPercentageDiscount(promo, paidRows, itemCategoryMap);
                        break;

                    case EnumHelper.PromotionType.BOGO_ITEM_CATEGORY:
                    case EnumHelper.PromotionType.BOGO_CART:
                        var bogoFreeItems = ApplyBogoPromotion(promo, paidRows, itemCategoryMap, result.Subtotal, salesId, payeeId);
                        result.FreeItemsAdded.AddRange(bogoFreeItems);
                        break;
                }

                if (promoDiscount > 0 || (promoType is EnumHelper.PromotionType.BOGO_ITEM_CATEGORY or EnumHelper.PromotionType.BOGO_CART
                    && result.FreeItemsAdded.Any(f => f.ItemId > 0)))
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

        #endregion


        #region --- Schedule Check ---

        private bool IsPromoValidForSchedule(Promotion promo, DateTime nowLocal)
        {
            if (promo.PromotionSchedules == null || !promo.PromotionSchedules.Any())
                return true; // No schedule restrictions = always valid within date range

            // Convert Sunday=0 to 7 to match common DB convention (1=Mon ... 7=Sun)
            var dow = (int)nowLocal.DayOfWeek == 0 ? 7 : (int)nowLocal.DayOfWeek;
            var time = nowLocal.TimeOfDay;

            return promo.PromotionSchedules.Any(s =>
                !s.IsClosed &&
                s.DayOfWeek == dow &&
                (
                    (s.StartTime == null && s.EndTime == null) ||
                    (s.StartTime != null && s.EndTime != null &&
                     time >= s.StartTime && time <= s.EndTime)
                ));
        }

        #endregion


        #region --- Cart-Level Discount Handlers ---

        private decimal ApplyDiscountFlat(Promotion promo, decimal subtotal)
        {
            if (promo.DiscountValue == null || promo.DiscountValue <= 0) return 0m;
            return Math.Min(promo.DiscountValue.Value, subtotal);
        }

        private decimal ApplyDiscountPercentage(Promotion promo, decimal subtotal)
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

            // No filter = all paid item rows qualify
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
                row.OrgPrice ??= row.UnitPrice;
                var newPrice = Math.Max(0m, (row.OrgPrice ?? 0m) - promo.DiscountValue.Value);
                var discountForRow = ((row.OrgPrice ?? 0m) - newPrice) * (row.BillQty ?? 0m);

                row.UnitPrice = newPrice;
                row.DiscountPercent = row.OrgPrice > 0
                    ? Math.Round((1 - newPrice / row.OrgPrice.Value) * 100, 4)
                    : 0;

                Uow.TempSales.Update(row);
                totalDiscount += discountForRow;
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
                row.OrgPrice ??= row.UnitPrice;
                var newPrice = Math.Max(0m, (row.OrgPrice ?? 0m) * (1 - promo.DiscountValue.Value / 100m));
                var discountForRow = ((row.OrgPrice ?? 0m) - newPrice) * (row.BillQty ?? 0m);

                row.UnitPrice = newPrice;
                row.DiscountPercent = promo.DiscountValue.Value;

                Uow.TempSales.Update(row);
                totalDiscount += discountForRow;
            }

            // Apply overall max cap if set
            if (promo.MaxDiscountAmount.HasValue)
                totalDiscount = Math.Min(totalDiscount, promo.MaxDiscountAmount.Value);

            return totalDiscount;
        }

        #endregion


        #region --- BOGO Handler ---

        private List<FreeItemSummary> ApplyBogoPromotion(
            Promotion promo,
            List<TempSales> paidRows,
            Dictionary<int, int?> itemCategoryMap,
            decimal subtotal,
            int salesId,
            int payeeId)
        {
            var freeItemsSummary = new List<FreeItemSummary>();

            if (promo.PromotionBogos == null || !promo.PromotionBogos.Any())
                return freeItemsSummary;

            // BogoMaxRewardRepeats = 0 means unlimited
            int maxRepeats = promo.BogoMaxRewardRepeats > 0 ? promo.BogoMaxRewardRepeats : int.MaxValue;

            foreach (var rule in promo.PromotionBogos)
            {
                if (!Enum.TryParse<EnumHelper.ConditionType>(rule.ConditionType, out var conditionType)) continue;
                if (!Enum.TryParse<EnumHelper.RewardType>(rule.RewardType, out var rewardType)) continue;
                if (!Enum.TryParse<EnumHelper.DiscountType>(rule.DiscountType, out var discountType)) continue;

                // Only insert free TempSales rows for FREE discount type
                if (discountType != EnumHelper.DiscountType.FREE) continue;
                if ((rule.RewardQty ?? 0) <= 0) continue;

                // Resolve the reward item ID based on RewardType
                // SAME_AS_CONDITION = free item is the same item as the qualifying condition
                int? resolvedRewardItemId = rewardType switch
                {
                    EnumHelper.RewardType.SAME_AS_CONDITION => rule.ConditionItemId,
                    EnumHelper.RewardType.ITEM               => rule.RewardItemId,
                    _                                        => null  // CATEGORY needs specific item — skip
                };

                if (!resolvedRewardItemId.HasValue) continue;

                // Determine how many reward sets this rule produces
                int sets = GetConditionSets(rule, conditionType, paidRows, itemCategoryMap, subtotal);
                if (sets <= 0) continue;

                sets = Math.Min(sets, maxRepeats);

                decimal totalRewardQty = sets * (rule.RewardQty ?? 1);

                // CART-level: one global free row (no parent link)
                if (conditionType == EnumHelper.ConditionType.CART)
                {
                    InsertFreeRow(salesId, payeeId, resolvedRewardItemId.Value, totalRewardQty, promo.Name, parentTempSalesId: null);
                }
                else
                {
                    // ITEM/CATEGORY: one free row per qualifying paid line, linked via SourceTempSalesId
                    var qualifyingRows = GetQualifyingRows(rule, conditionType, paidRows, itemCategoryMap);

                    foreach (var qualRow in qualifyingRows)
                    {
                        decimal rowQty = qualRow.OrdQty ?? 0;
                        if ((rule.ConditionQty ?? 0) <= 0 || rowQty <= 0) continue;

                        int rowSets = (int)Math.Floor(rowQty / rule.ConditionQty!.Value);
                        rowSets = Math.Min(rowSets, maxRepeats);

                        if (rowSets <= 0) continue;

                        decimal rowRewardQty = rowSets * (rule.RewardQty ?? 1);
                        InsertFreeRow(salesId, payeeId, resolvedRewardItemId.Value, rowRewardQty, promo.Name, parentTempSalesId: qualRow.TempSalesId);
                    }
                }

                freeItemsSummary.Add(new FreeItemSummary
                {
                    ItemId = resolvedRewardItemId.Value,
                    Qty = totalRewardQty
                });
            }

            return freeItemsSummary;
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

        private void InsertFreeRow(int salesId, int payeeId, int rewardItemId, decimal rewardQty, string? promoName, int? parentTempSalesId)
        {
            var freeRow = new TempSales
            {
                SalesId = salesId,
                PayeeId = payeeId,
                EmpId = UserContext.EmpId,
                ItemId = rewardItemId,
                LineType = EnumHelper.LineType.I.ToString(),
                SourceTempSalesId = parentTempSalesId
            };

            freeRow.ApplyEdits(rewardQty, isFree: true, isOut: false, isCrcg: false, unitPrice: 0m, notes: $"FREE - {promoName}");
            Uow.TempSales.Add(freeRow);
        }

        #endregion


        #region --- Helpers ---

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
            catch { /* fallback to server local time */ }

            return DateTime.Now;
        }

        #endregion
    }
}
