using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Models;
using Microsoft.EntityFrameworkCore;

namespace KLS.Services
{
    public class PromotionEvaluationService : BaseService, IPromotionEvaluationService
    {
        private readonly IItemUnitService _itemUnitService;

        public PromotionEvaluationService(IUnitOfWork uow, IItemUnitService itemUnitService) : base(uow)
        {
            _itemUnitService = itemUnitService;
        }

        public PromotionEvalResponse EvaluateCart(PromotionEvalRequest request)
        {
            var response = new PromotionEvalResponse();
            var log = response.DebugLog;

            log.Add($"[START] EmpId={request.EmpId}, SalesId={request.SalesId}, PayeeId={request.PayeeId}");
            log.Add($"[START] EnabledPromos={request.EnabledPromos?.Count ?? 0}");
            if (request.EnabledPromos != null)
            {
                foreach (var ep in request.EnabledPromos)
                    log.Add($"  EnabledPromo: TempSalesId={ep.TempSalesId}, PromotionId={ep.PromotionId}");
            }

            // 1. Get cart items (TempSales entities, not DTOs)
            var cartItems = Uow.TempSales.Find(c =>
                c.EmpId == request.EmpId &&
                c.SalesId == request.SalesId &&
                c.PayeeId == request.PayeeId &&
                c.LineType == EnumHelper.LineType.I.ToString()
            ).ToList();

            log.Add($"[STEP1] Cart items found: {cartItems.Count}");
            foreach (var ci in cartItems)
                log.Add($"  Item: TempSalesId={ci.TempSalesId}, ItemId={ci.ItemId}, OrdQty={ci.OrdQty}, Notes={ci.Notes}");

            if (!cartItems.Any()) { log.Add("[EXIT] No cart items"); return response; }

            // 2. Clean existing promo lines
            CleanPromoLines(cartItems);

            // Re-fetch after cleaning (promo lines removed)
            cartItems = Uow.TempSales.Find(c =>
                c.EmpId == request.EmpId &&
                c.SalesId == request.SalesId &&
                c.PayeeId == request.PayeeId &&
                c.LineType == EnumHelper.LineType.I.ToString()
            ).ToList()
            .Where(c => c.Notes == null || !c.Notes.StartsWith("[PROMO:"))
            .ToList();

            log.Add($"[STEP2] After clean, cart items: {cartItems.Count}");

            if (!cartItems.Any()) { log.Add("[EXIT] No cart items after clean"); return response; }

            // 3. Check HasOwnList for customer
            var payee = Uow.Payees.GetById(request.PayeeId);
            bool hasOwnList = payee?.HasOwnList ?? false;
            log.Add($"[STEP3] HasOwnList={hasOwnList}");

            // 4. Get active promotions with BOGO rules
            var activePromos = GetActivePromotions();
            log.Add($"[STEP4] Active promos: {activePromos.Count}");
            foreach (var ap in activePromos)
                log.Add($"  Promo: Id={ap.PromotionId}, Name={ap.Name}, Bogos={ap.PromotionBogos?.Count ?? 0}");

            if (!activePromos.Any()) { log.Add("[EXIT] No active promos"); return response; }

            // 5. Evaluate each promotion — one result per matching cart line
            foreach (var promo in activePromos)
            {
                var bogos = promo.PromotionBogos?.ToList() ?? new List<PromotionBogo>();
                if (!bogos.Any()) { log.Add($"  Promo {promo.PromotionId}: no bogos, skip"); continue; }

                foreach (var bogo in bogos)
                {
                    log.Add($"  Evaluating bogo {bogo.PromotionBogoId}: CondType={bogo.ConditionType}, CondItemId={bogo.ConditionItemId}, CondQty={bogo.ConditionQty}, RewQty={bogo.RewardQty}, PromoPrice={bogo.PromoPrice}");
                    var results = EvaluateBogoPerItem(promo, bogo, cartItems, hasOwnList, request.PayeeId);
                    foreach (var result in results)
                    {
                        log.Add($"  -> Match! TempSalesId={result.MatchingTempSalesIds[0]}, Badge={result.BadgeText}");
                        response.AvailablePromotions.Add(result);
                    }
                    if (!results.Any()) log.Add($"  -> No match");
                }
            }

            // 6. Apply enabled promos (reprice + insert free lines)
            if (request.EnabledPromos != null && request.EnabledPromos.Any())
            {
                log.Add($"[STEP6] Applying {request.EnabledPromos.Count} enabled promos");
                ApplyEnabledPromos(response.AvailablePromotions, request.EnabledPromos, cartItems, request, log);
            }
            else
            {
                log.Add("[STEP6] No enabled promos to apply");
            }

            return response;
        }

        private void CleanPromoLines(List<TempSales> cartItems)
        {
            var promoLines = cartItems.Where(c => c.Notes != null && c.Notes.StartsWith("[PROMO:")).ToList();

            foreach (var line in promoLines)
            {
                Uow.TempSales.Remove(line);
            }

            // Restore original prices on repriced items
            var repricedItems = cartItems.Where(c =>
                c.OrgPrice.HasValue && c.OrgPrice.Value != 0 &&
                c.Notes != null && c.Notes.Contains("[REPRICED:")
            ).ToList();

            foreach (var item in repricedItems)
            {
                item.UnitPrice = item.OrgPrice;
                item.OrgPrice = null;
                item.DiscountPercent = null;

                // Remove [REPRICED:xx] tag from notes
                if (item.Notes != null)
                {
                    item.Notes = System.Text.RegularExpressions.Regex.Replace(
                        item.Notes, @"\[REPRICED:\d+\]", "").Trim();
                    if (string.IsNullOrEmpty(item.Notes)) item.Notes = null;
                }

                Uow.TempSales.Update(item);
            }

            if (promoLines.Any() || repricedItems.Any())
                Uow.Commit();
        }

        private List<Promotion> GetActivePromotions()
        {
            var now = DateTime.UtcNow;
            var today = DateOnly.FromDateTime(now);

            return Uow.Promotions.Find(p => p.IsActive)
                .Include(p => p.PromotionBogos)
                .Include(p => p.PromotionSchedules)
                .Include(p => p.PromotionCategories)
                .Include(p => p.PromotionItems)
                .Where(p =>
                    (!p.StartDate.HasValue || p.StartDate.Value <= today) &&
                    (!p.EndDate.HasValue || p.EndDate.Value >= today)
                )
                .ToList()
                .Where(p => IsPromoActiveNow(p, now))
                .ToList();
        }

        private bool IsPromoActiveNow(Promotion promo, DateTime now)
        {
            if (promo.PromotionSchedules == null || !promo.PromotionSchedules.Any())
                return true; // no schedule = always active

            var dayOfWeek = (int)now.DayOfWeek;
            var schedule = promo.PromotionSchedules.FirstOrDefault(s => s.DayOfWeek == dayOfWeek);

            if (schedule == null) return true;
            if (schedule.IsClosed) return false;

            var currentTime = now.TimeOfDay;

            if (schedule.StartTime.HasValue && currentTime < schedule.StartTime.Value)
                return false;

            if (schedule.EndTime.HasValue && currentTime > schedule.EndTime.Value)
                return false;

            return true;
        }

        /// <summary>
        /// Returns one PromotionEvalResult per matching cart line (each line is independent).
        /// </summary>
        private List<PromotionEvalResult> EvaluateBogoPerItem(
            Promotion promo,
            PromotionBogo bogo,
            List<TempSales> cartItems,
            bool hasOwnList,
            int payeeId)
        {
            var results = new List<PromotionEvalResult>();

            var matchingItems = GetConditionMatchingItems(bogo, cartItems);
            if (!matchingItems.Any()) return results;

            decimal conditionQty = bogo.ConditionQty ?? 1;
            decimal rewardQty = bogo.RewardQty ?? 1;
            decimal? promoPrice = bogo.PromoPrice;

            // Build badge text once (same for all items in this bogo)
            decimal? actualAfterPromo = null;
            decimal? savings = null;
            decimal? p1 = null;

            // Get P1 from first matching item's base unit (all same item type)
            var firstItem = matchingItems.First();
            if (firstItem.ItemId.HasValue)
            {
                var baseUnit = _itemUnitService.GetBaseUnit(firstItem.ItemId.Value);
                if (baseUnit != null) p1 = baseUnit.P1;
            }

            if (promoPrice.HasValue && promoPrice.Value > 0 && conditionQty > 0)
            {
                actualAfterPromo = Math.Round(
                    (promoPrice.Value * conditionQty) / (conditionQty + rewardQty), 2);
                if (p1.HasValue)
                    savings = Math.Round(p1.Value - actualAfterPromo.Value, 2);
            }

            string badgeText = BuildBadgeText(promo, bogo, promoPrice, actualAfterPromo, savings);

            // Evaluate each matching cart line independently
            foreach (var item in matchingItems)
            {
                // HasOwnList + TargetPrice bypass check per item
                if (hasOwnList && item.ItemId.HasValue)
                {
                    var baseUnit = _itemUnitService.GetBaseUnit(item.ItemId.Value);
                    if (baseUnit != null)
                    {
                        var quote = Uow.ItemQuotes.Find(q =>
                            q.PayeeId == payeeId &&
                            q.ItemUnitId == baseUnit.ItemUnitId &&
                            !q.Inactive
                        ).FirstOrDefault();

                        if (quote != null && quote.TargetPrice.HasValue && quote.TargetPrice.Value != 0)
                            continue; // skip this item — customer has custom pricing
                    }
                }

                results.Add(new PromotionEvalResult
                {
                    PromotionId = promo.PromotionId,
                    PromotionBogoId = bogo.PromotionBogoId,
                    DisplayName = promo.DisplayName ?? promo.Name,
                    PromotionType = promo.PromotionType,
                    IsApplicable = true,
                    PromoPrice = promoPrice,
                    ActualAfterPromo = actualAfterPromo,
                    Savings = savings,
                    ConditionQty = conditionQty,
                    RewardQty = rewardQty,
                    MatchingTempSalesIds = new List<int> { item.TempSalesId },
                    BadgeText = badgeText
                });
            }

            return results;
        }

        private List<TempSales> GetConditionMatchingItems(PromotionBogo bogo, List<TempSales> cartItems)
        {
            switch (bogo.ConditionType?.ToUpper())
            {
                case "ITEM":
                    return cartItems.Where(c =>
                        c.ItemId == bogo.ConditionItemId &&
                        !c.IsFree && !c.IsOut
                    ).ToList();

                case "CATEGORY":
                    if (!bogo.ConditionCategoryId.HasValue) return new List<TempSales>();

                    var categoryItemIds = Uow.Items.Find(i =>
                        i.CategoryId == bogo.ConditionCategoryId.Value && !i.Inactive
                    ).Select(i => i.ItemId).ToList();

                    return cartItems.Where(c =>
                        c.ItemId.HasValue &&
                        categoryItemIds.Contains(c.ItemId.Value) &&
                        !c.IsFree && !c.IsOut
                    ).ToList();

                case "CART":
                    return cartItems.Where(c => !c.IsFree && !c.IsOut).ToList();

                default:
                    return new List<TempSales>();
            }
        }

        private string BuildBadgeText(
            Promotion promo,
            PromotionBogo bogo,
            decimal? promoPrice,
            decimal? actualAfterPromo,
            decimal? savings)
        {
            string displayName = promo.DisplayName ?? promo.Name ?? "Promotion";
            string condQty = (bogo.ConditionQty ?? 1).ToString("0");
            string rewQty = (bogo.RewardQty ?? 1).ToString("0");

            string promoDesc = $"Buy {condQty} Get {rewQty} Free";

            var parts = new List<string> { promoDesc };

            if (promoPrice.HasValue && promoPrice.Value > 0)
                parts.Insert(0, $"${promoPrice.Value:F2}");

            if (actualAfterPromo.HasValue)
                parts.Add($"actual cost ${actualAfterPromo.Value:F2}");

            if (savings.HasValue && savings.Value > 0)
                parts.Add($"you save ${savings.Value:F2}");

            return string.Join(", ", parts);
        }

        private void ApplyEnabledPromos(
            List<PromotionEvalResult> availablePromos,
            List<PromoToggle> enabledPromos,
            List<TempSales> cartItems,
            PromotionEvalRequest request,
            List<string> log)
        {
            // Build set of enabled TempSalesIds for quick lookup
            var enabledSet = enabledPromos.ToHashSet(
                new PromoToggleComparer());

            log.Add($"  Enabled toggles: {enabledPromos.Count}");
            log.Add($"  AvailablePromos count: {availablePromos.Count}");

            foreach (var result in availablePromos)
            {
                // Each result has exactly one TempSalesId
                int tempSalesId = result.MatchingTempSalesIds[0];

                // Check if this specific item+promo is enabled
                bool isEnabled = enabledPromos.Any(e =>
                    e.TempSalesId == tempSalesId && e.PromotionId == result.PromotionId);

                if (!isEnabled)
                {
                    log.Add($"  TempSalesId={tempSalesId}, Promo={result.PromotionId} -> not enabled, skip");
                    continue;
                }

                var cartItem = cartItems.FirstOrDefault(c => c.TempSalesId == tempSalesId);
                if (cartItem == null) { log.Add($"  TempSalesId={tempSalesId} not found in cart, skip"); continue; }

                // Reprice this item to PromoPrice
                if (result.PromoPrice.HasValue && result.PromoPrice.Value > 0)
                {
                    if (!cartItem.OrgPrice.HasValue || cartItem.OrgPrice.Value == 0)
                        cartItem.OrgPrice = cartItem.UnitPrice;

                    cartItem.UnitPrice = result.PromoPrice.Value;

                    if (cartItem.OrgPrice.HasValue && cartItem.OrgPrice.Value > 0)
                    {
                        cartItem.DiscountPercent = Math.Round(
                            ((cartItem.OrgPrice.Value - result.PromoPrice.Value) / cartItem.OrgPrice.Value) * 100, 4);
                    }

                    string repricedTag = $"[REPRICED:{result.PromotionId}]";
                    if (cartItem.Notes == null || !cartItem.Notes.Contains(repricedTag))
                    {
                        cartItem.Notes = string.IsNullOrEmpty(cartItem.Notes)
                            ? repricedTag
                            : $"{cartItem.Notes} {repricedTag}";
                    }

                    Uow.TempSales.Update(cartItem);
                    log.Add($"  Repriced TempSalesId={tempSalesId}: UnitPrice={cartItem.UnitPrice}, OrgPrice={cartItem.OrgPrice}");
                }

                // Calculate reward qty for THIS item's qty only
                decimal itemQty = Math.Abs(cartItem.OrdQty ?? 0);
                decimal conditionQty = result.ConditionQty ?? 1;
                decimal rewardQty = result.RewardQty ?? 1;

                int rewardSets = (int)Math.Floor(itemQty / conditionQty);

                var promo = Uow.Promotions.GetById(result.PromotionId);
                if (promo != null && promo.BogoMaxRewardRepeats > 0)
                    rewardSets = Math.Min(rewardSets, promo.BogoMaxRewardRepeats);

                decimal totalRewardQty = rewardSets * rewardQty;
                log.Add($"  TempSalesId={tempSalesId}: itemQty={itemQty}, condQty={conditionQty}, rewQty={rewardQty}, rewardSets={rewardSets}, totalReward={totalRewardQty}");

                if (totalRewardQty > 0)
                {
                    var bogo = Uow.PromotionBogos.GetById(result.PromotionBogoId);
                    int? rewardItemId = ResolveRewardItemId(bogo, new List<TempSales> { cartItem });

                    if (rewardItemId.HasValue)
                    {
                        InsertPromoRewardLine(rewardItemId.Value, totalRewardQty, result.PromotionId, tempSalesId, request);
                        log.Add($"  -> Inserted reward line for TempSalesId={tempSalesId}: ItemId={rewardItemId.Value}, Qty={totalRewardQty}");
                    }
                }
                else
                {
                    log.Add($"  -> No free line (qty {itemQty} < conditionQty {conditionQty})");
                }
            }

            Uow.Commit();
            log.Add("[STEP6] Commit done");
        }

        private class PromoToggleComparer : IEqualityComparer<PromoToggle>
        {
            public bool Equals(PromoToggle? x, PromoToggle? y) =>
                x?.TempSalesId == y?.TempSalesId && x?.PromotionId == y?.PromotionId;
            public int GetHashCode(PromoToggle obj) =>
                HashCode.Combine(obj.TempSalesId, obj.PromotionId);
        }

        private int? ResolveRewardItemId(PromotionBogo bogo, List<TempSales> conditionItems)
        {
            switch (bogo.RewardType?.ToUpper())
            {
                case "SAME_AS_CONDITION":
                    return conditionItems.FirstOrDefault()?.ItemId;

                case "ITEM":
                    return bogo.RewardItemId;

                case "CATEGORY":
                    if (!bogo.RewardCategoryId.HasValue) return null;
                    // Pick the first item from the reward category that's in stock
                    var categoryItem = Uow.Items.Find(i =>
                        i.CategoryId == bogo.RewardCategoryId.Value && !i.Inactive
                    ).FirstOrDefault();
                    return categoryItem?.ItemId;

                default:
                    return conditionItems.FirstOrDefault()?.ItemId;
            }
        }

        private void InsertPromoRewardLine(
            int rewardItemId,
            decimal rewardQty,
            int promotionId,
            int sourceTempSalesId,
            PromotionEvalRequest request)
        {
            var item = Uow.Items.GetById(rewardItemId);
            if (item == null) return;

            var baseUnit = _itemUnitService.GetBaseUnit(rewardItemId);
            if (baseUnit == null) return;

            var tempSales = new TempSales
            {
                PayeeId = request.PayeeId,
                SalesId = request.SalesId,
                EmpId = request.EmpId,
                ItemId = rewardItemId,
                LineType = EnumHelper.LineType.I.ToString()
            };

            tempSales.ApplyUnit(baseUnit.Unit, baseUnit.ItemUnitId, baseUnit.FactorToBase);
            tempSales.ApplyEdits(
                ordQty: rewardQty,
                isFree: true,
                isOut: false,
                isCrcg: false,
                unitPrice: 0,
                notes: $"[PROMO:{promotionId}:{sourceTempSalesId}]"
            );

            Uow.TempSales.Add(tempSales);
        }
    }
}
