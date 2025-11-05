using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Models;
using KLS.Services.Interfaces;
using Microsoft.AspNetCore.DataProtection.KeyManagement;
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
        private readonly IAccountService _accountService;

        public TempPurchaseService(IUnitOfWork uow, IItemService itemService, IAccountService accountService) : base(uow)
        {
            _itemService = itemService;
            _accountService = accountService;
        }

        public IEnumerable<TempPurchaseItem>? GetTempPurchaseItems(TempPurchaseReq tempReq)
        {
            return Uow.TempPayrollServices.GetTempPurchaseItems(tempReq);
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
            var existing = Uow.TempPurchases.GetById(tempPurchase.TempPurchaseId);

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

                Uow.TempPurchases.Update(existing);
                Uow.Commit();
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
                    temp.ChangeStatus = EnumHelper.ChangeStatus.D.ToString();
                    Uow.TempPurchases.Update(temp);
                }
                else
                {
                    Uow.TempPurchases.Remove(temp);
                }
                Uow.Commit();
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
                throw new InvalidOperationException("Item code not found");

            if (item.Inactive)
                throw new InvalidOperationException("This product already discontinue");

            var itemCategory = Uow.ItemCategories.GetById(item.CategoryId ?? 0);
            tempItem.CustomDutyRate = itemCategory?.CustomDutyRate ?? 0;

            tempItem.ItemId = item.ItemId;
            tempItem.ItemCode = item.ItemCode;
            tempItem.CaseWeight = item.CaseWeight;
            tempItem.CaseVolume = item.CaseVolume;
            tempItem.BillPrice = tempItem.BillPrice == 0 ? item.DefaultCost ?? 0 : 0;
            tempItem.FinalPrice = tempItem.BillPrice;
            tempItem.OrgPrice = tempItem.BillPrice;

            var tempPurchase = new TempPurchase();
            tempPurchase.InjectFrom(tempItem);
            tempPurchase.EmpId = UserContext.EmpId;

            Uow.TempPurchases.Add(tempPurchase);
            Uow.Commit();

            tempItem.TempPurchaseId = tempPurchase.TempPurchaseId;

            return tempItem;
        }

        private TempPurchaseItem AddAccount(TempPurchaseItem tempItem)
        {
            var account = _accountService.CheckAccount(tempItem.ItemCode);

            if (account == null)
                throw new InvalidOperationException("Account not found");

            if ((account.AccountType.CatName == EnumHelper.AccountCategory.Income.ToString() || account.AccountType.CatName == EnumHelper.AccountCategory.Liability.ToString()))
                throw new InvalidOperationException("You can't add Income/Liability account");

            tempItem.ItemCode = account.AccountCode;
            tempItem.ItemName = account.AccountName;
            tempItem.AccountId = account.AccountId;
            tempItem.LineType = EnumHelper.LineType.A.ToString();

            var tempPurchase = new TempPurchase();
            tempPurchase.InjectFrom(tempItem);
            tempPurchase.EmpId = UserContext.EmpId;

            Uow.TempPurchases.Add(tempPurchase);
            Uow.Commit();

            tempItem.TempPurchaseId = tempPurchase.TempPurchaseId;

            return tempItem;
        }
    }
}
