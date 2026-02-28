using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Models;
using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services
{
    public class PromotionService : BaseService, IPromotionService
    {
        public PromotionService(IUnitOfWork uow) : base(uow)
        {

        }

        public PagingResponse<PromotionList> GetPagedList(PromotionListReq promotionListReq)
        {
            var loglist = Uow.Promotions.GetPagedList(promotionListReq);

            var totalRecords = Uow.Promotions.Count(promotionListReq);

            return new PagingResponse<PromotionList>(totalRecords, promotionListReq.Pageno, promotionListReq.Pagesize)
            {
                RowData = loglist,
            };
        }

        public Promotion GetById(int promotionId)
        {
            return Uow.Promotions.Find(c => c.PromotionId == promotionId)
                .Include(c => c.PromotionSchedules)
                .Include(c => c.PromotionCategories)
                .Include(c => c.PromotionItems)
                .Include(c => c.PromotionBogos)
                .FirstOrDefault();
        }

        public bool ExistsName(Promotion promotion)
        {
            var type = promotion.PromotionType?.Trim().ToLower() ?? "";

            return Uow.Promotions.Exists(c => c.Name.ToLower() == promotion.Name.ToLower()
            && c.PromotionType == type && c.PromotionId != promotion.PromotionId);
        }

        public Promotion Create(Promotion promotion)
        {
            //var incomingCats = promotion.PromotionCategories?.ToList() ?? [];
            //var incomingItems = promotion.PromotionItems?.ToList() ?? [];
            //var incomingBogos = promotion.PromotionBogos?.ToList() ?? [];

            // remove them to avoid EF trying to insert before Promotion has PK (optional)
            //promotion.PromotionCategories = [];
            //promotion.PromotionItems = [];
            //promotion.PromotionBogos = [];

            Uow.Promotions.Add(promotion);
            Uow.Commit();

            //// --- Insert Categories ---
            //foreach (var c in incomingCats)
            //{
            //    var pc = new PromotionCategory { PromotionId = promotion.PromotionId, CategoryId = c.CategoryId };
            //    Uow.PromotionCategories.Add(pc);
            //}

            //// --- Insert Items ---
            //foreach (var i in incomingItems)
            //{
            //    var pi = new PromotionItem { PromotionId = promotion.PromotionId, ItemId = i.ItemId };
            //    Uow.PromotionItems.Add(pi);
            //}

            //// --- Insert BOGO rules ---
            //foreach (var b in incomingBogos)
            //{
            //    b.PromotionId = promotion.PromotionId;
            //    Uow.PromotionBogos.Add(b);
            //}

            //Uow.Commit();

            //var times = Uow.PromotionSchedules.Find(c => c.PromotionId == promotion.PromotionId);

            //foreach (var time in times)
            //{
            //    time.StartTime = time.StartTime;
            //    time.EndTime = time.EndTime;

            //    Uow.PromotionSchedules.Update(time);
            //}

            //Uow.Commit();

            return promotion;
        }

        public Promotion? Update(Promotion promotion)
        {
            var oldpromo = GetById(promotion.PromotionId);

            if (oldpromo != null)
            {
                oldpromo.Name = promotion.Name;
                oldpromo.DisplayName = promotion.DisplayName;
                oldpromo.PromotionType = promotion.PromotionType;
                oldpromo.DiscountValue = promotion.DiscountValue;
                oldpromo.MaxDiscountAmount = promotion.MaxDiscountAmount;
                oldpromo.MinOrderAmount = promotion.MinOrderAmount;
                oldpromo.StartDate = promotion.StartDate;
                oldpromo.EndDate = promotion.EndDate;
                oldpromo.IsActive = promotion.IsActive;
                oldpromo.IsFirstOrderOnly = promotion.IsFirstOrderOnly;
                oldpromo.BogoMaxRewardRepeats = promotion.BogoMaxRewardRepeats;
                oldpromo.UpdatedAt = promotion.UpdatedAt;

                Uow.Promotions.Update(oldpromo);
                Uow.Commit();

                // 1) Update schedules
                var promotionSchedules = Uow.PromotionSchedules.Find(c => c.PromotionId == promotion.PromotionId);

                foreach (var time in promotionSchedules)
                {
                    var newTime = promotion.PromotionSchedules.Where(c => c.PromotionScheduleId == time.PromotionScheduleId).FirstOrDefault();

                    time.IsClosed = newTime.IsClosed;
                    time.StartTime = newTime.StartTime;
                    time.EndTime = newTime.EndTime;

                    Uow.PromotionSchedules.Update(time);
                }
                Uow.Commit();

                // 2) Update PromotionCategories
                var existingCats = Uow.PromotionCategories.Find(c => c.PromotionId == promotion.PromotionId).ToList();

                foreach (var ex in existingCats) Uow.PromotionCategories.Remove(ex);
                Uow.Commit();

                if (promotion.PromotionCategories != null && promotion.PromotionCategories.Any())
                {
                    foreach (var c in promotion.PromotionCategories)
                    {
                        Uow.PromotionCategories.Add(new PromotionCategory { PromotionId = promotion.PromotionId, CategoryId = c.CategoryId });
                    }
                    Uow.Commit();
                }

                // 3) Update PromotionItems
                var existingItems = Uow.PromotionItems.Find(c => c.PromotionId == promotion.PromotionId).ToList();

                foreach (var ex in existingItems) Uow.PromotionItems.Remove(ex);
                Uow.Commit();

                if (promotion.PromotionItems != null && promotion.PromotionItems.Any())
                {
                    foreach (var i in promotion.PromotionItems)
                    {
                        Uow.PromotionItems.Add(new PromotionItem { PromotionId = promotion.PromotionId, ItemId = i.ItemId });
                    }
                    Uow.Commit();
                }

                // 4) Update BOGO rules
                var existingBogos = Uow.PromotionBogos.Find(c => c.PromotionId == promotion.PromotionId).ToList();

                var incomingBogos = promotion.PromotionBogos?.ToList() ?? new List<PromotionBogo>();
                var deletedIds = promotion.DeletedBogoIds ?? new List<int>();

                // remove deleted rules
                if (deletedIds.Any())
                {
                    foreach (var id in deletedIds)
                    {
                        var rule = existingBogos.FirstOrDefault(x => x.PromotionBogoId == id);
                        if (rule != null)
                            Uow.PromotionBogos.Remove(rule);
                    }
                    Uow.Commit();
                }

                // update rules
                foreach (var newRule in incomingBogos)
                {
                    newRule.PromotionId = promotion.PromotionId;

                    if (newRule.PromotionBogoId > 0)
                    {
                        // update existing
                        var oldRule = existingBogos.FirstOrDefault(x => x.PromotionBogoId == newRule.PromotionBogoId);
                        if (oldRule != null)
                        {
                            oldRule.ConditionType = newRule.ConditionType;
                            oldRule.ConditionItemId = newRule.ConditionItemId;
                            oldRule.ConditionCategoryId = newRule.ConditionCategoryId;
                            oldRule.ConditionQty = newRule.ConditionQty;
                            oldRule.ConditionMinAmount = newRule.ConditionMinAmount;
                            oldRule.RewardType = newRule.RewardType;
                            oldRule.RewardItemId = newRule.RewardItemId;
                            oldRule.RewardCategoryId = newRule.RewardCategoryId;
                            oldRule.RewardQty = newRule.RewardQty;
                            oldRule.DiscountType = newRule.DiscountType;
                            oldRule.DiscountValue = newRule.DiscountValue;

                            Uow.PromotionBogos.Update(oldRule);
                        }
                    }
                    else
                    {
                        // new rule
                        Uow.PromotionBogos.Add(newRule);
                    }
                }
                Uow.Commit();
            }

            return oldpromo;
        }

        public void Delete(int promotionId)
        {
            Uow.Promotions.RemoveById(promotionId);
            Uow.Commit();
        }

        public ICollection<PromotionSchedule>? GetDefaultTimes()
        {
            var weekdays = Enum.GetValues(typeof(DayOfWeek)).Cast<DayOfWeek>().ToList();
            var promotionSchedules = new List<PromotionSchedule>();

            foreach (var week in weekdays)
            {
                promotionSchedules.Add(new PromotionSchedule
                {
                    PromotionId = 0,
                    DayOfWeek = (int)week
                });
            }

            return promotionSchedules;
        }

        public void UpdateStatus(int promotionId)
        {
            var oldpromo = GetById(promotionId);

            if (oldpromo != null)
            {
                oldpromo.IsActive = !oldpromo.IsActive;
                oldpromo.UpdatedAt = DateTime.UtcNow;

                Uow.Promotions.Update(oldpromo);
                Uow.Commit();
            }
        }
    }
}
