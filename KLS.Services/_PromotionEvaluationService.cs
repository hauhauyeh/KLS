// ================================================================================
// BACKUP — Pre-centralization snapshot of PromotionEvaluationService.
// Kept as read-only reference. Do NOT edit. Do NOT register for DI.
// See d:\KLS\AI-Development\plan\promo-centralization.md.
// ================================================================================

using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Models;
using KLS.Models.PromotionEval;
using Microsoft.EntityFrameworkCore;
using System;
using System.Collections.Generic;
using System.Linq;

namespace KLS.Services
{
    public class _PromotionEvaluationService : BaseService, _IPromotionEvaluationService
    {
        public _PromotionEvaluationService(IUnitOfWork uow) : base(uow)
        {
        }

        public PromotionEvalResponse EvaluateCart(PromotionEvalRequest request)
        {
            var empty = new PromotionEvalResponse();

            var customer = Uow.Customers.Find(c => c.PayeeId == request.PayeeId).FirstOrDefault();
            if (customer == null) return empty;
            if (customer.HasOwnList) return empty;
            if (!customer.IsPromotionEnabled) return empty;

            var localNow = GetLocalNow();
            var localDate = DateOnly.FromDateTime(localNow);
            var localTime = localNow.TimeOfDay;
            var localDayOfWeek = (int)localNow.DayOfWeek;

            var promotions = Uow.Promotions.Find(p => p.IsActive)
                .Include(p => p.PromotionBogos)
                .Include(p => p.PromotionSchedules)
                .Where(p => p.StartDate == null || p.StartDate <= localDate)
                .Where(p => p.EndDate == null || p.EndDate >= localDate)
                .ToList();

            var scheduledPromos = promotions.Where(p => IsWithinSchedule(p, localDayOfWeek, localTime)).ToList();

            var bogoRules = scheduledPromos
                .SelectMany(p => (p.PromotionBogos ?? Enumerable.Empty<PromotionBogo>())
                    .Where(b => b.ConditionType == "ITEM"
                        && (b.RewardType == "SAME_AS_CONDITION" || b.RewardType == "ITEM")
                        && b.DiscountType == "FREE"
                        && b.PromoPrice != null)
                    .Select(b => new { Promotion = p, Bogo = b }))
                .ToList();

            if (!bogoRules.Any()) return empty;

            var cartItems = Uow.TempSales.Find(t =>
                    t.EmpId == UserContext.EmpId
                    && t.SalesId == request.SalesId
                    && t.PayeeId == request.PayeeId
                    && t.LineType == "I"
                    && t.CartLineType == "MAIN"
                    && t.SalesDetailId == null)
                .ToList();

            if (!cartItems.Any()) return empty;

            var cartItemIds = cartItems.Select(c => c.TempSalesId).ToList();
            var links = Uow.TempSalesPromos.Find(l =>
                    cartItemIds.Contains(l.OwnerTempSalesId))
                .Select(l => new PromoLink
                {
                    OwnerTempSalesId = l.OwnerTempSalesId,
                    PromoTempSalesId = l.PromoTempSalesId
                }).ToArray();

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
            var existingLink = Uow.TempSalesPromos.Find(l =>
                l.OwnerTempSalesId == request.OwnerTempSalesId
                && l.PromotionBogoId == request.PromotionBogoId).FirstOrDefault();
            if (existingLink != null) return EvaluateCart(evalRequest);

            var owner = Uow.TempSales.GetById(request.OwnerTempSalesId);
            if (owner == null) return EvaluateCart(evalRequest);

            if (owner.CartLineType != "MAIN" || owner.IsSystemManaged || owner.SalesDetailId != null)
                return EvaluateCart(evalRequest);

            var bogo = Uow.PromotionBogos.GetById(request.PromotionBogoId);

            if (bogo == null || bogo.PromotionId != request.PromotionId)
                return EvaluateCart(evalRequest);

            var promotion = Uow.Promotions.GetById(bogo.PromotionId);
            if (promotion == null) return EvaluateCart(evalRequest);

            if (owner.ItemId != bogo.ConditionItemId)
                return EvaluateCart(evalRequest);

            var existingReward = Uow.TempSales
                .Find(t => t.ParentTempSalesId == owner.TempSalesId
                    && t.CartLineType == "PROMO_REWARD")
                .FirstOrDefault();
            if (existingReward != null)
                return EvaluateCart(evalRequest);

            var conditionQty = bogo.ConditionQty ?? 1;
            if (conditionQty <= 0) conditionQty = 1;

            if ((owner.OrdQty ?? 0) < conditionQty)
            {
                owner.ApplyEdits(conditionQty, owner.IsFree, owner.IsOut, owner.IsCRCG, owner.UnitPrice, owner.Notes);
            }

            if (owner.OrgPrice == null)
                owner.OrgPrice = owner.UnitPrice;

            owner.UnitPrice = bogo.PromoPrice;

            Uow.TempSales.Update(owner);

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
            else
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
            if (maxRepeats > 0 && sets > maxRepeats)
                sets = maxRepeats;

            var newRewardQty = sets * rewardQtyPerSet;

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

            Uow.TempSales.Add(rewardLine);

            Uow.Commit();

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
            var link = Uow.TempSalesPromos.Find(l =>
                l.OwnerTempSalesId == request.OwnerTempSalesId
                && l.PromotionBogoId == request.PromotionBogoId).FirstOrDefault();

            if (link == null) return EvaluateCart(evalRequest);

            Uow.TempSalesPromos.Remove(link);
            Uow.Commit();

            Uow.TempSales.Find(t => t.TempSalesId == link.PromoTempSalesId).ExecuteDelete();

            var owner = Uow.TempSales.GetById(request.OwnerTempSalesId);
            if (owner == null)
            {
                Uow.Commit();
                return EvaluateCart(evalRequest);
            }

            if (owner.OrgPrice != null)
            {
                owner.UnitPrice = owner.OrgPrice;
                owner.OrgPrice = null;
            }

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

            if (schedules == null || !schedules.Any())
                return true;

            var todaySchedule = schedules.FirstOrDefault(s => s.DayOfWeek == dayOfWeek);

            if (todaySchedule == null)
                return false;

            if (todaySchedule.IsClosed)
                return false;

            if (!todaySchedule.StartTime.HasValue && !todaySchedule.EndTime.HasValue)
                return true;

            var start = todaySchedule.StartTime ?? TimeSpan.Zero;
            var end = todaySchedule.EndTime ?? new TimeSpan(23, 59, 59);

            return localTime >= start && localTime <= end;
        }
    }
}
