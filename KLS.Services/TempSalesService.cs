using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Models;
using Microsoft.EntityFrameworkCore;
using Omu.ValueInjecter;
using System;
using System.Collections.Generic;
using System.Linq;

namespace KLS.Services
{
    public class TempSalesService : BaseService, ITempSalesService
    {
        private readonly IItemService _itemService;
        private readonly IItemUnitService _itemUnitService;
        private readonly IAccountService _accountService;

        public TempSalesService(IUnitOfWork uow, IItemService itemService, IItemUnitService itemUnitService, IAccountService accountService) : base(uow)
        {
            _itemService = itemService;
            _itemUnitService = itemUnitService;
            _accountService = accountService;
        }


        public IEnumerable<TempSalesItem>? GetList(TempSalesReq tempReq)
        {
            return Uow.TempSales.GetList(tempReq);
        }

        public TempSales? GetById(int tempId)
        {
            return Uow.TempSales.GetById(tempId);
        }

        public TempSalesItem GetListById(TempSales tempSales)
        {
            var tempReq = new TempSalesReq
            {
                PayeeId = tempSales.PayeeId,
                SalesId = tempSales.SalesId,
                TempId = tempSales.TempSalesId
            };

            return Uow.TempSales.GetList(tempReq).AsEnumerable().FirstOrDefault();
        }

        public TempSalesItem Create(TempSalesItem tempItem)
        {
            if (tempItem.LineType == EnumHelper.LineType.A.ToString() || tempItem.ItemCode.StartsWith('@'))
                return AddAccount(tempItem);
            else
                return AddItem(tempItem);
        }

        public TempSalesItem Update(TempSalesItem tempItem)
        {
            var existing = GetById(tempItem.TempSalesId);

            if (existing != null)
            {
                // --- NEW: change unit logic (only when keyboxUnit has value) ---
                if (tempItem.IsUnitChange && tempItem.LineType == EnumHelper.LineType.I.ToString())
                {
                    var resolvedUnit = _itemUnitService.ResolveKeyboxUnit(existing.ItemId ?? 0, tempItem.Unit);

                    if (resolvedUnit != null)
                    {
                        // update unit on existing
                        existing.ApplyUnit(resolvedUnit.Unit, resolvedUnit.ItemUnitId, resolvedUnit.FactorToBase);

                        // If user didn't type a manual price, refresh from pricing for the NEW unit
                        if (!tempItem.UnitPrice.HasValue || tempItem.UnitPrice.Value == 0)
                        {
                            var itemPriceForUnit = _itemUnitService.GetItemPriceByCustomer(
                                tempItem.PayeeId,
                                existing.ItemId ?? 0,
                                resolvedUnit.ItemUnitId
                            );

                            tempItem.UnitPrice = itemPriceForUnit.DefaultPrice;
                        }
                    }
                }

                //set default price when click O button
                if (tempItem.IsDefaultPrice && tempItem.LineType == EnumHelper.LineType.I.ToString())
                {
                    var itemPrice = _itemUnitService.GetItemPriceByCustomer(tempItem.PayeeId, existing.ItemId ?? 0, existing.ItemUnitId);
                    tempItem.UnitPrice = itemPrice.DefaultPrice;
                }

                existing.ApplyEdits(tempItem.OrdQty, tempItem.IsFree, tempItem.IsOut, tempItem.IsCRCG, tempItem.UnitPrice, tempItem.Notes);

                if (existing.SalesDetailId.HasValue)
                    existing.ChangeStatus = EnumHelper.ChangeStatus.U.ToString();

                existing.IsStrike = tempItem.IsStrike;

                Uow.TempSales.Update(existing);
                Uow.Commit();

                // --- Promo auto-sync ---
                SyncPromoAfterUpdate(existing);

                tempItem.InjectFrom(existing);
                tempItem.IsDefaultPrice = false;
            }

            return tempItem;
        }

        private void SyncPromoAfterUpdate(TempSales existing)
        {
            // Only MAIN rows trigger promo sync — prevents reward lines from causing recursive logic
            if (existing.CartLineType != "MAIN")
                return;

            // Double guard: system-managed rows should never trigger promo logic
            if (existing.IsSystemManaged)
                return;

            // Check if this owner has an active promo link
            var promoLink = Uow.TempSalesPromos.Find(l => l.OwnerTempSalesId == existing.TempSalesId).FirstOrDefault();
            if (promoLink == null)
                return;

            // Load BOGO rule and parent promotion once
            var bogo = Uow.PromotionBogos.GetById(promoLink.PromotionBogoId);
            if (bogo == null)
                return;

            var promotion = Uow.Promotions.GetById(promoLink.PromotionId);

            // Defensive check: verify reward line still exists
            var rewardLine = Uow.TempSales.GetById(promoLink.PromoTempSalesId);
            if (rewardLine == null)
            {
                // Reward line missing (orphaned link) — clean up link and restore owner price
                Uow.TempSalesPromos.Remove(promoLink);
                if (existing.OrgPrice != null)
                {
                    existing.UnitPrice = existing.OrgPrice;
                    existing.OrgPrice = null;
                }
                Uow.TempSales.Update(existing);
                Uow.Commit();
                return;
            }

            var conditionQty = bogo.ConditionQty ?? 1;
            if (conditionQty <= 0)
                conditionQty = 1;

            var rewardQtyPerSet = bogo.RewardQty ?? 0;
            if (rewardQtyPerSet < 0)
                rewardQtyPerSet = 0;

            var ownerQty = existing.OrdQty ?? 0;
            var maxRepeats = promotion?.BogoMaxRewardRepeats ?? 0;

            var sets = Math.Floor(ownerQty / conditionQty);
            if (maxRepeats > 0 && sets > maxRepeats)
                sets = maxRepeats;

            var newRewardQty = sets * rewardQtyPerSet;

            if (newRewardQty <= 0)
            {
                // Owner qty dropped below threshold → remove link first (FK), then reward line, restore price
                Uow.TempSalesPromos.Remove(promoLink);
                Uow.Commit();
                Uow.TempSales.Find(t => t.TempSalesId == promoLink.PromoTempSalesId).ExecuteDelete();

                if (existing.OrgPrice != null)
                {
                    existing.UnitPrice = existing.OrgPrice;
                    existing.OrgPrice = null;
                }
                Uow.TempSales.Update(existing);
                Uow.Commit();
            }
            else if (rewardLine.OrdQty != newRewardQty)
            {
                // Update reward line qty (only if changed)
                rewardLine.ApplyEdits(newRewardQty, true, false, false, 0, rewardLine.Notes);
                Uow.TempSales.Update(rewardLine);
                Uow.Commit();
            }
        }

        public TempSalesItem UpdateUnit(TempSalesItem tempItem)
        {
            var existing = GetById(tempItem.TempSalesId);

            if (existing != null)
            {
                if (!existing.ItemId.HasValue)
                    throw new InvalidOperationException("ItemId is required to update unit.");

                var itemUnit = _itemUnitService.GetNextUnit(existing.ItemId.Value, existing.Unit);
                var itemPrice = _itemUnitService.GetItemPriceByCustomer(existing.PayeeId, existing.ItemId.Value, itemUnit.ItemUnitId);

                existing.ApplyUnit(itemUnit.Unit, itemUnit.ItemUnitId, itemUnit.FactorToBase);

                existing.UnitPrice = itemPrice.DefaultPrice;

                if (existing.SalesDetailId.HasValue)
                    existing.ChangeStatus = EnumHelper.ChangeStatus.U.ToString();

                Uow.TempSales.Update(existing);
                Uow.Commit();

                tempItem.InjectFrom(existing);
            }

            return tempItem;
        }

        public void Delete(int tempId)
        {
            // Check if this item owns any promo links
            var promoLinks = Uow.TempSalesPromos
                .Find(l => l.OwnerTempSalesId == tempId)
                .ToList();

            foreach (var link in promoLinks)
            {
                Uow.TempSalesPromos.Remove(link);
            }

            if (promoLinks.Any())
                Uow.Commit();

            foreach (var link in promoLinks)
            {
                Uow.TempSales.Find(t => t.TempSalesId == link.PromoTempSalesId).ExecuteDelete();
            }

            // Also clean up links where this item is the reward (defensive)
            var rewardLinks = Uow.TempSalesPromos
                .Find(l => l.PromoTempSalesId == tempId)
                .ToList();

            foreach (var link in rewardLinks)
            {
                var owner = Uow.TempSales.GetById(link.OwnerTempSalesId);
                if (owner != null && owner.OrgPrice != null)
                {
                    owner.UnitPrice = owner.OrgPrice;
                    owner.OrgPrice = null;
                    Uow.TempSales.Update(owner);
                }
                Uow.TempSalesPromos.Remove(link);
            }

            if (rewardLinks.Any())
                Uow.Commit();

            // --- Structural child cleanup (covers historical injected rows without TempSalesPromo links) ---
            var structuralChildren = Uow.TempSales
                .Find(t => t.ParentTempSalesId == tempId && t.CartLineType == "PROMO_REWARD")
                .ToList();

            foreach (var child in structuralChildren)
            {
                if (child.SalesDetailId.HasValue)
                {
                    // Historical injected reward — soft-delete so Sales_PartialUpdate removes the SalesDetail row
                    Uow.TempSales.Find(c => c.TempSalesId == child.TempSalesId)
                        .ExecuteUpdate(setters => setters.SetProperty(x => x.ChangeStatus, x => EnumHelper.ChangeStatus.D.ToString()));
                }
                else
                {
                    // Newly added reward (no SalesDetail) — hard-delete
                    Uow.TempSales.Find(c => c.TempSalesId == child.TempSalesId).ExecuteDelete();
                }
            }

            // Original delete logic
            var temp = Uow.TempSales.GetById(tempId);

            if (temp != null)
            {
                if (temp.SalesDetailId.HasValue)
                {
                    // Soft-delete the parent row
                    Uow.TempSales.Find(c => c.TempSalesId == tempId)
                        .ExecuteUpdate(setters => setters.SetProperty(x => x.ChangeStatus, x => EnumHelper.ChangeStatus.D.ToString()));
                    // Soft-delete any promo free child rows linked to this parent
                    Uow.TempSales.Find(c => c.SourceTempSalesId == tempId)
                        .ExecuteUpdate(setters => setters.SetProperty(x => x.ChangeStatus, x => EnumHelper.ChangeStatus.D.ToString()));
                }
                else
                {
                    // Hard-delete child free rows first, then parent
                    Uow.TempSales.Find(c => c.SourceTempSalesId == tempId).ExecuteDelete();
                    Uow.TempSales.Find(c => c.TempSalesId == tempId).ExecuteDelete();
                }
            }
        }

        public void Clear(TempSalesReq tempReq)
        {
            // Get all TempSalesIds for this cart scope
            var cartIds = Uow.TempSales
                .Find(c => c.EmpId == UserContext.EmpId && c.SalesId == tempReq.SalesId && c.PayeeId == tempReq.PayeeId)
                .Select(c => c.TempSalesId)
                .ToList();

            // Delete all promo links referencing these cart items (both owner and reward sides)
            if (cartIds.Any())
            {
                Uow.TempSalesPromos
                    .Find(l => cartIds.Contains(l.OwnerTempSalesId)
                            || cartIds.Contains(l.PromoTempSalesId))
                    .ExecuteDelete();
            }

            // Then delete all cart items
            Uow.TempSales.Find(c => c.EmpId == UserContext.EmpId && c.SalesId == tempReq.SalesId && c.PayeeId == tempReq.PayeeId).ExecuteDelete();
        }

        public IEnumerable<PayeeSearch>? DraftCustomers()
        {
            var items = Uow.TempSales.Find(c => c.EmpId == UserContext.EmpId && c.SalesId == 0);

            return (from t in items
                    join p in Uow.Payees.GetAll() on t.PayeeId equals p.PayeeId
                    select new PayeeSearch
                    {
                        PayeeId = p.PayeeId,
                        PayeeName = p.PayeeName
                    }).Distinct().OrderBy(c => c.PayeeName);
        }

        public IEnumerable<ItemSearch> Search(TempSalesReq tempReq)
        {
            return Uow.TempSales.Search(tempReq);
        }

        private TempSalesItem AddItem(TempSalesItem tempItem)
        {
            var item = _itemService.GetBySearch(tempItem.ItemCode);

            if (item == null)
                throw new KeyNotFoundException("Product code not found");

            if (item.Inactive)
                throw new KeyNotFoundException("This product already discontinue");

            var tempSales = new TempSales
            {
                PayeeId = tempItem.PayeeId,
                SalesId = tempItem.SalesId,
                EmpId = UserContext.EmpId,
                ItemId = item.ItemId,
                LineType = EnumHelper.LineType.I.ToString(),
                LineId = tempItem.LineId
            };

            var resolvedUnit = _itemUnitService.ResolveKeyboxUnit(item.ItemId, tempItem.Unit);

            var itemPrice = _itemUnitService.GetItemPriceByCustomer(tempItem.PayeeId, item.ItemId, resolvedUnit?.ItemUnitId);

            decimal? custPrice = itemPrice.DefaultPrice;
            var unitPrice = (tempItem.UnitPrice.HasValue && tempItem.UnitPrice.Value != 0) ? tempItem.UnitPrice : (custPrice ?? 0m);

            tempSales.ApplyEdits(tempItem.OrdQty, tempItem.IsFree, tempItem.IsOut, tempItem.IsCRCG, unitPrice, tempItem.Notes);

            tempSales.ApplyUnit(itemPrice.DefaultUnit, itemPrice.ItemUnitId, itemPrice.FactorToBase);

            Uow.TempSales.Add(tempSales);
            Uow.Commit();

            return GetListById(tempSales);
        }

        private TempSalesItem AddAccount(TempSalesItem tempItem)
        {
            var account = _accountService.CheckAccount(tempItem.ItemCode);

            if (account == null)
                throw new KeyNotFoundException("Account not found");

            if (account.AccountCategory.ClassCode == EnumHelper.AccountClass.A.ToString() || account.AccountCategory.ClassCode == EnumHelper.AccountClass.X.ToString())
                throw new KeyNotFoundException("You can't add Expense/Asset account");

            var tempSales = new TempSales
            {
                PayeeId = tempItem.PayeeId,
                SalesId = tempItem.SalesId,
                EmpId = UserContext.EmpId,
                AccountId = account.AccountId,
                LineType = EnumHelper.LineType.A.ToString(),
                LineId = tempItem.LineId
            };

            var unitPrice = (tempItem.UnitPrice.HasValue && tempItem.UnitPrice.Value != 0) ? tempItem.UnitPrice : 0m;

            tempSales.ApplyEdits(tempItem.OrdQty, tempItem.IsFree, tempItem.IsOut, tempItem.IsCRCG, unitPrice, null);

            Uow.TempSales.Add(tempSales);
            Uow.Commit();

            return GetListById(tempSales);
        }
    }
}
