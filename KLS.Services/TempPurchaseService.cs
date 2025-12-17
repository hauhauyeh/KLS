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

        public IEnumerable<TempPurchaseItem>? GetTempPurchaseItems(TempPurchaseReq tempReq)
        {
            return Uow.TempPurchases.GetTempPurchaseItems(tempReq);
        }

        public TempPurchase? GetById(int tempId)
        {
            return Uow.TempPurchases.GetById(tempId);
        }

        public TempPurchaseItem CreateTempPurchase(TempPurchaseItem tempItem)
        {
            if (tempItem.LineType == EnumHelper.LineType.A.ToString() || tempItem.ItemCode.StartsWith('@'))
                return AddAccount(tempItem);
            else
                return AddItem(tempItem);
        }

        public TempPurchaseItem UpdateTempPurchase(TempPurchaseItem tempPurchase)
        {
            var existing = GetById(tempPurchase.TempPurchaseId);

            if (existing != null)
            {
                existing.OrdQty0 = tempPurchase.OrdQty0;
                existing.OrdQty1 = tempPurchase.OrdQty1;
                existing.BillPrice = tempPurchase.BillPrice;
                existing.FinalPrice = tempPurchase.FinalPrice;
                existing.IsFree = tempPurchase.IsFree;
                existing.IsOut = tempPurchase.IsOut;
                existing.IsCRCG = tempPurchase.IsCRCG;
                existing.Notes = tempPurchase.Notes;
                existing.ExpiryDate = tempPurchase.ExpiryDate;

                if (existing.PurchaseDetailId.HasValue)
                    existing.ChangeStatus = EnumHelper.ChangeStatus.U.ToString();

                existing.SetQtyBasedOnFlag();

                Uow.TempPurchases.Update(existing);
                Uow.Commit();

                tempPurchase.InjectFrom(existing);
            }

            return tempPurchase;
        }

        public TempPurchaseItem UpdateUnit(TempPurchaseItem tempPurchase)
        {
            var existing = GetById(tempPurchase.TempPurchaseId);

            if (existing != null)
            {
                var itemUnit = _itemUnitService.GetNextUnit(existing.ItemId ?? 0, existing.Unit);

                existing.Unit = itemUnit.Unit;
                existing.FactorToBase = itemUnit.FactorToBase;

                if (existing.PurchaseDetailId.HasValue)
                    existing.ChangeStatus = EnumHelper.ChangeStatus.U.ToString();                    

                existing.SetQtyBasedOnFlag();

                Uow.TempPurchases.Update(existing);
                Uow.Commit();

                tempPurchase.InjectFrom(existing);
            }

            return tempPurchase;
        }

        public void DeleteTempPurchase(int tempId)
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

        public void ClearTempPurchase(TempPurchaseReq tempReq)
        {
            Uow.TempPurchases.Find(c => c.EmpId == UserContext.EmpId && c.PayeeId == tempReq.PayeeId && c.PurchaseId == tempReq.PurchaseId).ExecuteDelete();
        }

        private TempPurchaseItem AddItem(TempPurchaseItem tempItem)
        {
            var item = _itemService.GetBySearch(tempItem.ItemCode);

            if (item == null)
                throw new KeyNotFoundException("Item code not found");

            if (item.Inactive)
                throw new KeyNotFoundException("This product already discontinue");

            var unit = _itemUnitService.GetBaseUnit(item.ItemId);

            var itemCategory = Uow.ItemCategories.GetById(item.CategoryId ?? 0);
            tempItem.CustomDutyRate = itemCategory?.CustomDutyRate ?? 0;

            tempItem.ItemId = item.ItemId;
            tempItem.ItemCode = item.ItemCode;
            tempItem.ItemName = item.ItemName;
            tempItem.CaseWeight = item.CaseWeight;
            tempItem.ItemVolume = item.CaseVolumeInCubicMeter;
            tempItem.BillPrice = tempItem.BillPrice == 0 ? unit.RecentCost ?? 0 : 0;
            tempItem.FinalPrice = tempItem.BillPrice;
            tempItem.OrgPrice = tempItem.BillPrice;
            tempItem.LineType = EnumHelper.LineType.I.ToString();

            tempItem.Unit = unit.Unit;
            tempItem.FactorToBase = unit.FactorToBase;

            var tempPurchase = new TempPurchase();
            tempPurchase.InjectFrom(tempItem);
            tempPurchase.EmpId = UserContext.EmpId;

            Uow.TempPurchases.Add(tempPurchase);
            Uow.Commit();

            Uow.TempPurchases.Reload(tempPurchase);

            tempItem.TempPurchaseId = tempPurchase.TempPurchaseId;
            tempItem.LineId = tempPurchase.LineId;

            return tempItem;
        }

        private TempPurchaseItem AddAccount(TempPurchaseItem tempItem)
        {
            var account = _accountService.CheckAccount(tempItem.ItemCode);

            if (account == null)
                throw new KeyNotFoundException("Account not found");

            if ((account.AccountType.CatName == EnumHelper.AccountCategory.Income.ToString() || account.AccountType.CatName == EnumHelper.AccountCategory.Liability.ToString()))
                throw new KeyNotFoundException("You can't add Income/Liability account");

            tempItem.ItemCode = account.AccountCode;
            tempItem.ItemName = account.AccountName;
            tempItem.AccountId = account.AccountId;
            tempItem.LineType = EnumHelper.LineType.A.ToString();

            var tempPurchase = new TempPurchase();
            tempPurchase.InjectFrom(tempItem);
            tempPurchase.EmpId = UserContext.EmpId;
            tempPurchase.BaseReceiveQty = tempItem.ReceiveQty;
            tempPurchase.BaseFinalQty = tempItem.FinalQty;
            tempPurchase.FactorToBase = 1;

            Uow.TempPurchases.Add(tempPurchase);
            Uow.Commit();

            Uow.TempPurchases.Reload(tempPurchase);

            tempItem.TempPurchaseId = tempPurchase.TempPurchaseId;
            tempItem.LineId = tempPurchase.LineId;

            return tempItem;
        }
    }
}
