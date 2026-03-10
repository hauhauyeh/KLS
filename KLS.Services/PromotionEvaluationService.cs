using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Models;
using KLS.Models.PromotionEval;
using KLS.Models.TempSalesPromo;
using Microsoft.EntityFrameworkCore;
using System;
using System.Collections.Generic;
using System.Linq;

namespace KLS.Services
{
    public class PromotionEvaluationService : BaseService, IPromotionEvaluationService
    {
        public PromotionEvaluationService(IUnitOfWork uow) : base(uow)
        {
        }

        public PromotionEvalResponse EvaluateCart(PromotionEvalRequest request)
        {
            var empty = new PromotionEvalResponse();

            // --- Bypass checks ---
            var customer = Uow.Customers.Find(c => c.PayeeId == request.PayeeId).FirstOrDefault();
            if (customer == null) return empty;
            if (customer.HasOwnList) return empty;
            if (!customer.IsPromotionEnabled) return empty;

            // --- Local time ---
            var localNow = GetLocalNow();
            var localDate = DateOnly.FromDateTime(localNow);
            var localTime = localNow.TimeOfDay;
            var localDayOfWeek = (int)localNow.DayOfWeek;

            // --- Load active promotions within date range ---
            var promotions = Uow.Promotions.Find(p => p.IsActive)
                .Include(p => p.PromotionBogos)
                .Include(p => p.PromotionSchedules)
                .Where(p => p.StartDate == null || p.StartDate <= localDate)
                .Where(p => p.EndDate == null || p.EndDate >= localDate)
                .ToList();

            // --- Filter by schedule ---
            var scheduledPromos = promotions.Where(p => IsWithinSchedule(p, localDayOfWeek, localTime)).ToList();

            // --- Extract BOGO rules (2C: PromoPrice != null, support ITEM reward type) ---
            var bogoRules = scheduledPromos
                .SelectMany(p => (p.PromotionBogos ?? Enumerable.Empty<PromotionBogo>())
                    .Where(b => b.ConditionType == "ITEM"
                        && (b.RewardType == "SAME_AS_CONDITION" || b.RewardType == "ITEM")
                        && b.DiscountType == "FREE"
                        && b.PromoPrice != null)
                    .Select(b => new { Promotion = p, Bogo = b }))
                .ToList();

            if (!bogoRules.Any()) return empty;

            // --- Load cart items (MAIN lines only) ---
            var cartItems = Uow.TempSales.Find(t =>
                    t.EmpId == UserContext.EmpId
                    && t.SalesId == request.SalesId
                    && t.PayeeId == request.PayeeId
                    && t.LineType == "I"
                    && t.CartLineType == "MAIN"
                    && t.SalesDetailId == null)
                .ToList();

            if (!cartItems.Any()) return empty;

            // --- Populate ActiveLinks from TempSalesPromo ---
            var cartItemIds = cartItems.Select(c => c.TempSalesId).ToList();
            var links = Uow.TempSalesPromos.Find(l =>
                    cartItemIds.Contains(l.OwnerTempSalesId))
                .Select(l => new PromoLink
                {
                    OwnerTempSalesId = l.OwnerTempSalesId,
                    PromoTempSalesId = l.PromoTempSalesId
                }).ToArray();

            // --- Match BOGO rules to cart items ---
            var results = new List<PromotionEvalResult>();

            foreach (var rule in bogoRules)
            {
                var matchingItems = cartItems
                    .Where(t => t.ItemId == rule.Bogo.ConditionItemId)
                    .ToList();

                if (!matchingItems.Any()) continue;

                results.Add(new PromotionEvalResult
                {
                    PromotionId = rule.Promotion.PromotionId,
                    PromotionBogoId = rule.Bogo.PromotionBogoId,
                    DisplayName = rule.Promotion.DisplayName ?? rule.Promotion.Name,
                    ConditionItemId = rule.Bogo.ConditionItemId ?? 0,
                    ConditionQty = rule.Bogo.ConditionQty ?? 0,
                    RewardQty = rule.Bogo.RewardQty ?? 0,
                    PromoPrice = rule.Bogo.PromoPrice,
                    BadgeText = $"Buy {rule.Bogo.ConditionQty} Get {rule.Bogo.RewardQty}",
                    MatchingTempSalesIds = matchingItems.Select(t => t.TempSalesId).ToArray()
                });
            }

            return new PromotionEvalResponse
            {
                AvailablePromotions = results.ToArray(),
                ActiveLinks = links
            };
        }

        public PromotionEvalResponse TogglePromotion(PromoToggleRequest request)
        {
            var evalRequest = new PromotionEvalRequest { SalesId = request.SalesId, PayeeId = request.PayeeId };

            if (request.Enable)
                return ToggleOn(request, evalRequest);
            else
                return ToggleOff(request, evalRequest);
        }

        private PromotionEvalResponse ToggleOn(PromoToggleRequest request, PromotionEvalRequest evalRequest)
        {
            // 1. Duplicate check — existing link
            var existingLink = Uow.TempSalesPromos.Find(l =>
                l.OwnerTempSalesId == request.OwnerTempSalesId
                && l.PromotionBogoId == request.PromotionBogoId).FirstOrDefault();
            if (existingLink != null) return EvaluateCart(evalRequest);

            // 2. Load owner line
            var owner = Uow.TempSales.GetById(request.OwnerTempSalesId);
            if (owner == null) return EvaluateCart(evalRequest);

            // 2b. Guard: only MAIN, non-system-managed, non-injected lines can toggle
            if (owner.CartLineType != "MAIN" || owner.IsSystemManaged || owner.SalesDetailId != null)
                return EvaluateCart(evalRequest);

            // 3. Load BOGO rule
            var bogo = Uow.PromotionBogos.GetById(request.PromotionBogoId);

            // 4. Validate PromotionId consistency
            if (bogo == null || bogo.PromotionId != request.PromotionId)
                return EvaluateCart(evalRequest);

            // 5. Load parent promotion (once)
            var promotion = Uow.Promotions.GetById(bogo.PromotionId);
            if (promotion == null) return EvaluateCart(evalRequest);

            // 6. Validate owner.ItemId matches bogo.ConditionItemId
            if (owner.ItemId != bogo.ConditionItemId)
                return EvaluateCart(evalRequest);

            // 7. Race condition guard — check if reward line already exists
            var existingReward = Uow.TempSales
                .Find(t => t.ParentTempSalesId == owner.TempSalesId
                    && t.CartLineType == "PROMO_REWARD")
                .FirstOrDefault();
            if (existingReward != null)
                return EvaluateCart(evalRequest);

            // 8. Quantity normalization
            var conditionQty = bogo.ConditionQty ?? 1;
            if (conditionQty <= 0) conditionQty = 1;

            if ((owner.OrdQty ?? 0) < conditionQty)
            {
                owner.ApplyEdits(conditionQty, owner.IsFree, owner.IsOut, owner.IsCRCG, owner.UnitPrice, owner.Notes);
            }

            // 9. Save OrgPrice (protect — once only)
            if (owner.OrgPrice == null)
                owner.OrgPrice = owner.UnitPrice;

            // 10. Reprice owner
            owner.UnitPrice = bogo.PromoPrice;

            // 11. Update owner — NO Commit yet
            Uow.TempSales.Update(owner);

            // 12. Determine reward item and unit fields
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

            // 13. Calculate reward qty using normalized owner qty
            var ownerQty = owner.OrdQty ?? 0;
            var rewardQtyPerSet = bogo.RewardQty ?? 0;
            var maxRepeats = promotion.BogoMaxRewardRepeats;

            var sets = Math.Floor(ownerQty / conditionQty);
            if (maxRepeats > 0 && sets > maxRepeats)
                sets = maxRepeats;

            var newRewardQty = sets * rewardQtyPerSet;

            // 14. Insert reward line
            var rewardLine = new TempSales();
            rewardLine.EmpId = owner.EmpId;
            rewardLine.SalesId = owner.SalesId;
            rewardLine.PayeeId = owner.PayeeId;
            rewardLine.ItemId = rewardItemId;
            rewardLine.CartLineType = "PROMO_REWARD";
            rewardLine.IsSystemManaged = true;
            rewardLine.ParentTempSalesId = owner.TempSalesId;
            rewardLine.RootTempSalesId = owner.TempSalesId;
            rewardLine.IsTaxable = owner.IsTaxable;
            rewardLine.LineType = "I";
            rewardLine.ApplyEdits(newRewardQty, true, false, false, 0, null);
            rewardLine.ApplyUnit(rewardUnit ?? "", rewardItemUnitId, rewardFactorToBase);
            rewardLine.DisplaySort = owner.LineId ?? 0;

            // 15. Add reward line — NO Commit yet
            Uow.TempSales.Add(rewardLine);

            // Commit #1 — persist owner update + reward line insert (generates rewardLine.TempSalesId)
            Uow.Commit();

            // Commit #2 — persist TempSalesPromo link (needs rewardLine.TempSalesId from Commit #1)
            var link = new TempSalesPromo();
            link.OwnerTempSalesId = owner.TempSalesId;
            link.PromoTempSalesId = rewardLine.TempSalesId;
            link.PromotionId = bogo.PromotionId;
            link.PromotionBogoId = bogo.PromotionBogoId;

            Uow.TempSalesPromos.Add(link);
            Uow.Commit();

            return EvaluateCart(evalRequest);
        }

        private PromotionEvalResponse ToggleOff(PromoToggleRequest request, PromotionEvalRequest evalRequest)
        {
            // 1. Find link
            var link = Uow.TempSalesPromos.Find(l =>
                l.OwnerTempSalesId == request.OwnerTempSalesId
                && l.PromotionBogoId == request.PromotionBogoId).FirstOrDefault();

            // 2. If no link → already off
            if (link == null) return EvaluateCart(evalRequest);

            // 3. Delete link first (FK constraint: TempSalesPromo references TempSales)
            Uow.TempSalesPromos.Remove(link);
            Uow.Commit();

            // 4. Delete reward line
            Uow.TempSales.Find(t => t.TempSalesId == link.PromoTempSalesId).ExecuteDelete();

            // 5. Load owner (defensive)
            var owner = Uow.TempSales.GetById(request.OwnerTempSalesId);
            if (owner == null)
            {
                // Owner missing — link and reward already deleted above, just commit and return
                Uow.Commit();
                return EvaluateCart(evalRequest);
            }

            // 6. Restore owner price (null-safe)
            if (owner.OrgPrice != null)
            {
                owner.UnitPrice = owner.OrgPrice;
                owner.OrgPrice = null;
            }

            // 7. Update owner → single Commit
            Uow.TempSales.Update(owner);
            Uow.Commit();

            return EvaluateCart(evalRequest);
        }

        private DateTime GetLocalNow()
        {
            var timezone = UserContext.UserTimezone;
            if (string.IsNullOrEmpty(timezone))
                return DateTime.Now;

            try
            {
                var tz = TimeZoneInfo.FindSystemTimeZoneById(timezone);
                return TimeZoneInfo.ConvertTimeFromUtc(DateTime.UtcNow, tz);
            }
            catch
            {
                return DateTime.Now;
            }
        }

        private static bool IsWithinSchedule(Promotion promo, int dayOfWeek, TimeSpan localTime)
        {
            var schedules = promo.PromotionSchedules;

            // No schedule rows → always active
            if (schedules == null || !schedules.Any())
                return true;

            var todaySchedule = schedules.FirstOrDefault(s => s.DayOfWeek == dayOfWeek);

            // No row for today → skip
            if (todaySchedule == null)
                return false;

            // Closed today → skip
            if (todaySchedule.IsClosed)
                return false;

            // Both times null → all day
            if (!todaySchedule.StartTime.HasValue && !todaySchedule.EndTime.HasValue)
                return true;

            // Check time window
            var start = todaySchedule.StartTime ?? TimeSpan.Zero;
            var end = todaySchedule.EndTime ?? new TimeSpan(23, 59, 59);

            return localTime >= start && localTime <= end;
        }
    }
}
