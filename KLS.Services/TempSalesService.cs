using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Models;
using KLS.Models.Cart;
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
        private readonly IItemImageService _itemImageService;
        private readonly IPortalModeService _portalModeService;
        private readonly IPromoHelperService _promoHelper;
        private readonly ISystemSettingService _systemSettingService;

        public TempSalesService(IUnitOfWork uow, IItemService itemService, IItemUnitService itemUnitService, IAccountService accountService, IItemImageService itemImageService, IPortalModeService portalModeService, IPromoHelperService promoHelper, ISystemSettingService systemSettingService) : base(uow)
        {
            _itemService = itemService;
            _itemUnitService = itemUnitService;
            _accountService = accountService;
            _itemImageService = itemImageService;
            _portalModeService = portalModeService;
            _promoHelper = promoHelper;
            _systemSettingService = systemSettingService;
        }

        public IEnumerable<TempSalesItem>? GetList(TempSalesReq tempReq)
        {
            return Uow.TempSales.GetList(tempReq)?.ToList();
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
                            var itemPrice = _itemUnitService.GetItemPriceByCustomer(
                                tempItem.PayeeId,
                                existing.ItemId ?? 0,
                                resolvedUnit.ItemUnitId
                            );

                            tempItem.UnitPrice = itemPrice?.DefaultPrice;
                        }

                        tempItem.ListPrice = resolvedUnit.P1;
                    }
                }

                //set default price when click O button
                if (tempItem.IsDefaultPrice && tempItem.LineType == EnumHelper.LineType.I.ToString())
                {
                    var itemPrice = _itemUnitService.GetItemPriceByCustomer(
                        tempItem.PayeeId,
                        existing.ItemId ?? 0,
                        existing.ItemUnitId
                    );

                    tempItem.UnitPrice = itemPrice?.DefaultPrice;
                }

                // 2026-08-29 plan-reprice-open-orders-v1 (D5): track rep price overrides.
                // "O" button (IsDefaultPrice) resets to the system price -> not manual.
                // Unit change refreshes the price from pricing when none was typed -> not manual.
                // Otherwise a changed UnitPrice on an item line is a manual override.
                var priceBefore = existing.UnitPrice;
                var systemPriced = tempItem.IsDefaultPrice
                    || (tempItem.IsUnitChange && (!tempItem.UnitPrice.HasValue || tempItem.UnitPrice.Value == 0));

                existing.ApplyEdits(tempItem.OrdQty, tempItem.IsFree, tempItem.IsOut, tempItem.IsCRCG, tempItem.UnitPrice, tempItem.Notes);

                if (existing.LineType == EnumHelper.LineType.I.ToString() && existing.CartLineType == "MAIN" && !existing.IsSystemManaged)
                {
                    if (systemPriced)
                        existing.IsManualPrice = false;
                    else if (existing.UnitPrice != priceBefore)
                        existing.IsManualPrice = true;
                }

                if (existing.SalesDetailId.HasValue)
                    existing.ChangeStatus = EnumHelper.ChangeStatus.U.ToString();

                existing.IsStrike = tempItem.IsStrike;

                Uow.TempSales.Update(existing);
                Uow.Commit();

                // --- Promo auto-sync ---
                SyncPromoAfterUpdate(existing);

                tempItem.InjectFrom(existing);
                // InjectFrom skips private-setter properties — copy them explicitly
                tempItem.Unit = existing.Unit;
                tempItem.ItemUnitId = existing.ItemUnitId;
                tempItem.OrdQty = existing.OrdQty;
                tempItem.ShipQty = existing.ShipQty;
                tempItem.BillQty = existing.BillQty;
                tempItem.IsFree = existing.IsFree;
                tempItem.IsOut = existing.IsOut;
                tempItem.IsCRCG = existing.IsCRCG;
                tempItem.IsDefaultPrice = false;
            }

            return tempItem;
        }

        public TempSalesItem UpdatePriceCommentOnly(TempSalesItem tempItem)
        {
            var existing = GetById(tempItem.TempSalesId)
                ?? throw new KeyNotFoundException("Temp sales line not found.");

            if (existing.EmpId != UserContext.EmpId)
                throw new UnauthorizedAccessException("Temp sales line does not belong to the current user.");

            if (!existing.SalesDetailId.HasValue)
                throw new ArgumentException("Only existing sales detail lines can use price/comment update.");

            var sales = Uow.Sales.GetById(existing.SalesId)
                ?? throw new KeyNotFoundException("Sales order not found.");

            if (sales.IsLocked || !sales.IsDropShip || sales.StageId < 2 || sales.StageId > 4)
                throw new ArgumentException("Only Transit, Received, or Success drop-ship lines can use restricted price/comment update.");

            existing.UnitPrice = tempItem.UnitPrice;
            existing.Notes = tempItem.Notes;
            existing.ChangeStatus = EnumHelper.ChangeStatus.U.ToString();

            Uow.TempSales.Update(existing);
            Uow.Commit();

            return GetListById(existing);
        }

        public TempSalesItem? UpdateParentSalesNumber(TempSalesParentUpdateReq req)
        {
            var existing = GetById(req.TempSalesId);

            if (existing == null)
                return null;

            existing.ParentSalesNumber = req.ParentSalesNumber;

            Uow.TempSales.Update(existing);
            Uow.Commit();

            return GetListById(existing);
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
                // InjectFrom skips private-setter properties — copy them explicitly
                tempItem.Unit = existing.Unit;
                tempItem.ItemUnitId = existing.ItemUnitId;
                tempItem.OrdQty = existing.OrdQty;
                tempItem.ShipQty = existing.ShipQty;
                tempItem.BillQty = existing.BillQty;
                tempItem.IsFree = existing.IsFree;
                tempItem.IsOut = existing.IsOut;
                tempItem.IsCRCG = existing.IsCRCG;
                tempItem.ListPrice = itemUnit.P1;
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

        public TempSalesItem? AddLine(AddLineRequest req)
        {
            return Uow.TempSales.AddLine(req);
        }

        private TempSalesItem AddItem(TempSalesItem tempItem)
        {
            var item = _itemService.GetBySearch(tempItem.ItemCode);

            if (item == null)
                throw new KeyNotFoundException($"Product code not found: {tempItem.ItemCode}");

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

            var unitPrice = (tempItem.UnitPrice.HasValue && tempItem.UnitPrice.Value != 0) ? tempItem.UnitPrice : (itemPrice.DefaultPrice ?? 0m);

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

        //---Web
        private ItemUnit? ResolveWebCartUnit(int itemId, int payeeId, int? itemUnitId, string? unit)
        {
            if (itemUnitId.HasValue)
            {
                var selected = Uow.ItemUnits.GetById(itemUnitId.Value);

                if (selected != null && selected.ItemId == itemId && !selected.Inactive)
                    return selected;
            }

            var resolvedUnit = _itemUnitService.ResolveKeyboxUnit(itemId, unit);

            if (resolvedUnit != null)
                return resolvedUnit;

            var itemPrice = _itemUnitService.GetItemPriceByCustomer(payeeId, itemId, null);

            return itemPrice.ItemUnitId > 0 ? Uow.ItemUnits.GetById(itemPrice.ItemUnitId) : null;
        }

        private decimal? ResolveWebCartPrice(int payeeId, int itemId, int? itemUnitId)
        {
            if (_portalModeService.IsB2C())
            {
                if (itemUnitId.HasValue)
                    return Uow.ItemUnits.GetById(itemUnitId.Value)?.P1;

                var itemPrice = _itemUnitService.GetItemPriceByCustomer(payeeId, itemId, null);

                return itemPrice.ItemUnitId > 0
                    ? Uow.ItemUnits.GetById(itemPrice.ItemUnitId)?.P1
                    : itemPrice.DefaultPrice;
            }

            return _itemUnitService.GetItemPriceByCustomer(payeeId, itemId, itemUnitId).DefaultPrice;
        }

        private TempSales? GetWebCartEntity(int tempSalesId)
        {
            var existing = GetById(tempSalesId);

            if (existing == null || existing.SalesId != 0 || existing.EmpId != UserContext.EmpId || existing.PayeeId != UserContext.EmpId)
                return null;

            return existing;
        }

        private WebCartItem? SaveWebCartRow(TempSales existing, decimal? ordQty, int? itemUnitId, string? unit, decimal? factorToBase, decimal? unitPrice, bool syncPromo)
        {
            var resolvedQty = ordQty ?? existing.OrdQty;
            var resolvedPrice = unitPrice ?? existing.UnitPrice;

            if (!string.IsNullOrWhiteSpace(unit))
                existing.ApplyUnit(unit, itemUnitId, factorToBase);

            existing.ApplyEdits(resolvedQty, existing.IsFree, existing.IsOut, existing.IsCRCG, resolvedPrice, existing.Notes);

            if (existing.SalesDetailId.HasValue)
                existing.ChangeStatus = EnumHelper.ChangeStatus.U.ToString();

            Uow.TempSales.Update(existing);
            Uow.Commit();

            if (syncPromo)
                SyncPromoAfterUpdate(existing);

            return ToWebCartItem(GetListById(existing));
        }

        private WebCartItem ToWebCartItem(TempSalesItem item, int? promotionId = null) => new WebCartItem
        {
            TempSalesId = item.TempSalesId,
            ItemId = item.ItemId,
            ItemCode = item.ItemCode,
            ItemName = item.ItemName,
            ItemUnitId = item.ItemUnitId,
            Unit = item.Unit,
            FactorToBase = item.FactorToBase,
            MultipleToBase = item.MultipleToBase,
            OrdQty = item.OrdQty,
            UnitPrice = item.UnitPrice,
            ExtTotal = item.ExtTotal,
            PrimaryImageUrl = item.ItemId.HasValue
                ? _itemImageService.GetPrimary(item.ItemId.Value)?.ThumbnailUrl
                : null,
            LCloseQty = item.ItemId.HasValue
                ? Uow.Items.GetById(item.ItemId.Value)?.LCloseQty
                : null,
            CartLineType = item.CartLineType,
            IsSystemManaged = item.IsSystemManaged,
            OrgPrice = item.OrgPrice,
            ParentTempSalesId = item.ParentTempSalesId,
            IsFree = item.IsFree,
            Notes = item.Notes,
            PromotionId = promotionId
        };

        public IEnumerable<WebCartItem>? GetCartItems()
        {
            var items = GetList(new TempSalesReq { PayeeId = UserContext.EmpId, SalesId = 0 })?.ToList();
            if (items == null) return null;

            var rewardIds = items
                .Where(i => i.CartLineType == "PROMO_REWARD")
                .Select(i => i.TempSalesId)
                .ToList();

            var promoMap = rewardIds.Count == 0
                ? new Dictionary<int, int>()
                : Uow.TempSalesPromos
                    .Find(p => rewardIds.Contains(p.PromoTempSalesId))
                    .ToDictionary(p => p.PromoTempSalesId, p => p.PromotionId);

            return items.Select(i =>
                ToWebCartItem(i, promoMap.TryGetValue(i.TempSalesId, out var pid) ? (int?)pid : null));
        }

        public int GetCartCount()
        {
            return GetCartItems()?.Count(i => (i.CartLineType ?? "MAIN") == "MAIN") ?? 0;
        }

        // Re-normalize promo state after any web-cart mutation. ApplyPromotion is
        // idempotent (it resets prior reward rows first), so safe to call on every
        // commit. No-op when the customer isn't eligible.
        private void ReapplyPromosForWebCart()
        {
            _promoHelper.ApplyPromotion(salesId: 0, payeeId: UserContext.EmpId);
        }

        // WEB_ENFORCE_STOCK_LIMIT: a unit is sellable on the web only if stock covers 1 whole unit.
        // BaseQty = Qty * MultipleToBase / FactorToBase, so whole units = LCloseQty * Factor / Multiple.
        // Works whether the base is the big unit (KLS: CS base, ÷N retail) or the small unit
        // (other clients: retail base, ×N case). Round to 4dp before Floor: base snapshots are
        // stored at 6dp, so a whole ÷12 unit round-trips as 0.999996 and a bare Floor would block it.
        private static decimal WholeUnitsAvailable(decimal lCloseQty, ItemUnit unit)
        {
            var factor = unit.FactorToBase <= 0 ? 1 : unit.FactorToBase;
            var multiple = unit.MultipleToBase <= 0 ? 1 : unit.MultipleToBase;
            return Math.Floor(Math.Round(lCloseQty * factor / multiple, 4));
        }

        private static bool IsUnitSellable(decimal lCloseQty, ItemUnit unit)
        {
            return WholeUnitsAvailable(lCloseQty, unit) >= 1;
        }

        private bool EnforceStockLimit()
        {
            return _systemSettingService.GetByKey<bool>(GlobalKey.WEB_ENFORCE_STOCK_LIMIT);
        }

        public IEnumerable<WebCartItem>? AddCartItem(AddToCartReq req)
        {
            var selectedUnit = ResolveWebCartUnit(req.ItemId, UserContext.EmpId, req.ItemUnitId, req.Unit);

            if (selectedUnit != null && EnforceStockLimit())
            {
                var lCloseQty = Uow.Items.GetById(req.ItemId)?.LCloseQty ?? 0;

                if (!IsUnitSellable(lCloseQty, selectedUnit))
                    return null;
            }

            var cartItems = GetList(new TempSalesReq { PayeeId = UserContext.EmpId, SalesId = 0 });

            var existing = cartItems?.FirstOrDefault(c =>
                c.ItemId == req.ItemId && c.ItemUnitId == selectedUnit?.ItemUnitId);

            if (existing != null)
            {
                var existingRow = GetWebCartEntity(existing.TempSalesId);

                if (existingRow == null)
                    return null;

                SaveWebCartRow(existingRow, (existingRow.OrdQty ?? 0) + req.Qty, null, null, null, existingRow.UnitPrice, false);
                ReapplyPromosForWebCart();
                return GetCartItems();
            }

            var addReq = new AddLineRequest
            {
                PayeeId = UserContext.EmpId,
                SalesId = 0,
                ItemId = req.ItemId,
                Qty = req.Qty,
                Unit = selectedUnit?.Unit ?? req.Unit
            };

            var result = AddLine(addReq);

            if (result == null)
                return null;

            var newRow = GetWebCartEntity(result.TempSalesId);

            if (newRow == null)
                return null;

            var price = ResolveWebCartPrice(UserContext.EmpId, req.ItemId, selectedUnit?.ItemUnitId ?? newRow.ItemUnitId);

            SaveWebCartRow(
                newRow,
                newRow.OrdQty,
                selectedUnit?.ItemUnitId ?? newRow.ItemUnitId,
                selectedUnit?.Unit ?? newRow.Unit,
                selectedUnit?.FactorToBase ?? newRow.FactorToBase,
                price ?? newRow.UnitPrice,
                false
            );
            ReapplyPromosForWebCart();
            return GetCartItems();
        }

        public IEnumerable<WebCartItem>? UpdateCartQty(WebCartItem cartItem)
        {
            var existing = GetWebCartEntity(cartItem.TempSalesId);

            if (existing == null)
                return null;

            SaveWebCartRow(existing, cartItem.OrdQty, null, null, null, existing.UnitPrice, false);
            ReapplyPromosForWebCart();
            return GetCartItems();
        }

        public IEnumerable<WebCartItem>? UpdateCartUnit(WebCartItem cartItem)
        {
            var existing = GetWebCartEntity(cartItem.TempSalesId);

            if (existing == null || !existing.ItemId.HasValue)
                return null;

            // Cycle to the next unit like GetNextUnit, but when WEB_ENFORCE_STOCK_LIMIT is on,
            // skip units whose stock can't cover 1 whole unit. With the setting off this picks
            // units[(idx + 1) % Count] — identical to GetNextUnit.
            var units = _itemUnitService.GetByItemId(existing.ItemId.Value);
            var enforce = EnforceStockLimit();
            var lCloseQty = Uow.Items.GetById(existing.ItemId.Value)?.LCloseQty ?? 0;
            var idx = units.FindIndex(u => u.Unit == existing.Unit);

            ItemUnit? nextUnit = null;

            for (var step = 1; step <= units.Count; step++)
            {
                var candidate = units[(idx + step) % units.Count];

                if (!enforce || IsUnitSellable(lCloseQty, candidate))
                {
                    nextUnit = candidate;
                    break;
                }
            }

            if (nextUnit == null || nextUnit.ItemUnitId == existing.ItemUnitId)
                return GetCartItems();   // nothing else sellable — keep current unit

            var qty = existing.OrdQty;

            if (enforce)
            {
                // Cap the carried-over qty at the new unit's whole-unit availability
                // (a 3-PACK line toggled to CS must not become 3 CS with only 1 in stock).
                var maxQty = WholeUnitsAvailable(lCloseQty, nextUnit);
                qty = Math.Max(1, Math.Min(qty ?? 1, maxQty));
            }

            var price = ResolveWebCartPrice(existing.PayeeId, existing.ItemId.Value, nextUnit.ItemUnitId);

            SaveWebCartRow(existing, qty, nextUnit.ItemUnitId, nextUnit.Unit, nextUnit.FactorToBase, price ?? existing.UnitPrice, false);
            ReapplyPromosForWebCart();
            return GetCartItems();
        }

        public void ClearCart()
        {
            Clear(new TempSalesReq { PayeeId = UserContext.EmpId, SalesId = 0 });
            ReapplyPromosForWebCart();
        }
    }
}
