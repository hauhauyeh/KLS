using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Models;
using Microsoft.EntityFrameworkCore;
using Omu.ValueInjecter;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services
{
    public class TempPurchaseService : BaseService, ITempPurchaseService
    {
        private readonly IItemService _itemService;
        private readonly IItemUnitService _itemUnitService;
        private readonly IAccountService _accountService;

        public TempPurchaseService(IUnitOfWork uow, IItemService itemService, IItemUnitService itemUnitService, IAccountService accountService) : base(uow)
        {
            _itemService = itemService;
            _itemUnitService = itemUnitService;
            _accountService = accountService;
        }

        public IEnumerable<TempPurchaseItem>? GetList(TempPurchaseReq tempReq)
        {
            return Uow.TempPurchases.GetList(tempReq);
        }

        public TempPurchase? GetById(int tempId)
        {
            return Uow.TempPurchases.GetById(tempId);
        }

        public TempPurchaseItem GetListById(int payeeId, int purchaseId, int tempId)
        {
            var tempReq = new TempPurchaseReq
            {
                PayeeId = payeeId,
                PurchaseId = purchaseId,
                TempId = tempId
            };

            return Uow.TempPurchases.GetList(tempReq).AsEnumerable().FirstOrDefault();
        }

        public TempPurchaseItem Create(TempPurchaseItem tempItem, EnumHelper.PurchaseDocType docType)
        {
            if (tempItem.LineType == EnumHelper.LineType.A.ToString() || tempItem.ItemCode.StartsWith('@'))
                return AddAccount(tempItem, docType);
            else
                return AddItem(tempItem, docType);
        }

        public TempPurchaseItem Update(TempPurchaseItem dto, EnumHelper.PurchaseDocType docType)
        {
            var existing = GetById(dto.TempPurchaseId);

            if (existing != null)
            {
                existing.ApplyCommonEdits(dto.IsFree, dto.IsOut, dto.IsCRCG, dto.BillPrice, dto.FinalPrice, dto.Notes, dto.ExpiryDate);

                if (docType == EnumHelper.PurchaseDocType.Bill)
                    existing.ApplyBill(dto.OrdQty0, dto.OrdQty1);
                else
                    existing.ApplyPO(dto.OrdQty0, dto.OrdQty1, dto.ShipQty);

                if (existing.PurchaseDetailId.HasValue)
                    existing.ChangeStatus = EnumHelper.ChangeStatus.U.ToString();

                existing.CustomDutyRate = dto.CustomDutyRate;
                existing.TariffPercent = dto.TariffPercent;

                Uow.TempPurchases.Update(existing);
                Uow.Commit();

                dto.InjectFrom(existing);
            }

            return dto;
        }

        public TempPurchaseItem UpdateUnit(TempPurchaseItem dto)
        {
            var existing = GetById(dto.TempPurchaseId);

            if (existing != null)
            {
                var itemUnit = _itemUnitService.GetNextUnit(existing.ItemId ?? 0, existing.Unit);

                existing.ApplyUnit(itemUnit.Unit, itemUnit.ItemUnitId, itemUnit.FactorToBase);

                if (existing.PurchaseDetailId.HasValue)
                    existing.ChangeStatus = EnumHelper.ChangeStatus.U.ToString();

                Uow.TempPurchases.Update(existing);
                Uow.Commit();

                dto.InjectFrom(existing);
            }

            return dto;
        }

        public void Delete(int tempId)
        {
            var temp = Uow.TempPurchases.GetById(tempId);

            if (temp != null)
            {
                if (temp.PurchaseDetailId.HasValue)
                {
                    Uow.TempPurchases.Find(c => c.TempPurchaseId == tempId).ExecuteUpdate(setters => setters.SetProperty(x => x.ChangeStatus, x => EnumHelper.ChangeStatus.D.ToString()));
                }
                else
                {
                    Uow.TempPurchases.Find(c => c.TempPurchaseId == tempId).ExecuteDelete();
                }
            }
        }

        public void Clear(TempPurchaseReq tempReq)
        {
            Uow.TempPurchases.Find(c => c.EmpId == UserContext.EmpId && c.PayeeId == tempReq.PayeeId && c.PurchaseId == tempReq.PurchaseId).ExecuteDelete();
        }

        private TempPurchaseItem AddItem(TempPurchaseItem dto, EnumHelper.PurchaseDocType docType)
        {
            var item = _itemService.GetBySearch(dto.ItemCode);

            if (item == null)
                throw new KeyNotFoundException("Item code not found");

            if (item.Inactive)
                throw new KeyNotFoundException("This product already discontinue");

            var tempPurchase = new TempPurchase
            {
                PayeeId = dto.PayeeId,
                PurchaseId = dto.PurchaseId,
                EmpId = UserContext.EmpId,
                ItemId = item.ItemId,
                ItemVolume = item.CaseVolumeInCubicMeter,
                LineType = EnumHelper.LineType.I.ToString(),
                LineId = dto.LineId
            };

            var unit = _itemUnitService.GetBaseUnit(item.ItemId);

            var itemCategory = Uow.ItemCategories.GetById(item.CategoryId ?? 0);
            tempPurchase.CustomDutyRate = itemCategory?.CustomDutyRate ?? 0;

            var billPrice = (dto.BillPrice.HasValue && dto.BillPrice.Value != 0) ? dto.BillPrice : (unit.RecentCost ?? 0m);

            tempPurchase.ApplyCommonEdits(dto.IsFree, dto.IsOut, dto.IsCRCG, billPrice, billPrice, dto.Notes, null);

            tempPurchase.ApplyUnit(unit.Unit, unit.ItemUnitId, unit.FactorToBase);

            if (docType == EnumHelper.PurchaseDocType.Bill)
                tempPurchase.ApplyBill(dto.OrdQty0, dto.OrdQty1);
            else
                tempPurchase.ApplyPO(dto.OrdQty0, dto.OrdQty1, dto.ShipQty);

            Uow.TempPurchases.Add(tempPurchase);
            Uow.Commit();

            return GetListById(dto.PayeeId, dto.PurchaseId, tempPurchase.TempPurchaseId);
        }

        private TempPurchaseItem AddAccount(TempPurchaseItem tempItem, EnumHelper.PurchaseDocType docType)
        {
            var account = _accountService.CheckAccount(tempItem.ItemCode);

            if (account == null)
                throw new KeyNotFoundException("Account not found");

            if (account.AccountType.AccountClass == EnumHelper.AccountClass.Income.ToString() || account.AccountType.AccountClass == EnumHelper.AccountClass.Liability.ToString())
                throw new KeyNotFoundException("You can't add Income/Liability account");

            var tempPurchase = new TempPurchase
            {
                PayeeId = tempItem.PayeeId,
                PurchaseId = tempItem.PurchaseId,
                EmpId = UserContext.EmpId,
                AccountId = account.AccountId,
                LineType = EnumHelper.LineType.A.ToString(),
                LineId = tempItem.LineId
            };

            var billPrice = (tempItem.BillPrice.HasValue && tempItem.BillPrice.Value != 0) ? tempItem.BillPrice : 0;

            tempPurchase.ApplyCommonEdits(tempItem.IsFree, tempItem.IsOut, tempItem.IsCRCG, billPrice, billPrice, null, null);

            tempPurchase.ApplyBill(tempItem.OrdQty0, tempItem.OrdQty1);

            Uow.TempPurchases.Add(tempPurchase);
            Uow.Commit();

            return GetListById(tempItem.PayeeId, tempItem.PurchaseId, tempPurchase.TempPurchaseId);
        }
    }
}
