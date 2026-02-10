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
                //set default price when click o button
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

                tempItem.InjectFrom(existing);
                tempItem.IsDefaultPrice = false;
            }

            return tempItem;
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
            var temp = Uow.TempSales.GetById(tempId);

            if (temp != null)
            {
                if (temp.SalesDetailId.HasValue)
                {
                    Uow.TempSales.Find(c => c.TempSalesId == tempId).ExecuteUpdate(setters => setters.SetProperty(x => x.ChangeStatus, x => EnumHelper.ChangeStatus.D.ToString()));
                }
                else
                {
                    Uow.TempSales.Find(c => c.TempSalesId == tempId).ExecuteDelete();
                }
            }
        }

        public void Clear(TempSalesReq tempReq)
        {
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
                throw new KeyNotFoundException("Item code not found");

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

            var itemPrice = _itemUnitService.GetItemPriceByCustomer(tempItem.PayeeId, item.ItemId, null);

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
