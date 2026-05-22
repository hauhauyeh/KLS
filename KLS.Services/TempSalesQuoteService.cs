using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Models;
using Microsoft.EntityFrameworkCore;
using Omu.ValueInjecter;

namespace KLS.Services
{
    public class TempSalesQuoteService : BaseService, ITempSalesQuoteService
    {
        private readonly IItemUnitService _itemUnitService;

        public TempSalesQuoteService(IUnitOfWork uow, IItemUnitService itemUnitService) : base(uow)
        {
            _itemUnitService = itemUnitService;
        }

        public IEnumerable<TempSalesQuoteItem>? GetList(TempSalesQuoteReq req)
        {
            return Uow.TempSalesQuotes.GetList(req)?.ToList();
        }

        public TempSalesQuoteItem Create(TempSalesQuoteItem tempItem)
        {
            var temp = new TempSalesQuote
            {
                EmpId = UserContext.EmpId,
                SalesQuoteId = tempItem.SalesQuoteId,
                PayeeId = tempItem.PayeeId,
                ItemId = tempItem.ItemId,
                ItemUnitId = tempItem.ItemUnitId,
                Unit = tempItem.Unit,
                OrdQty = tempItem.OrdQty,
                UnitPrice = tempItem.UnitPrice,
                FactorToBase = tempItem.FactorToBase ?? 1,
                DiscountPercent = tempItem.DiscountPercent,
                Notes = tempItem.Notes,
                IsTaxable = tempItem.IsTaxable,
                ChangeStatus = "I",
                IsStrike = false
            };

            Uow.TempSalesQuotes.Add(temp);
            Uow.Commit();

            var req = new TempSalesQuoteReq
            {
                PayeeId = tempItem.PayeeId,
                SalesQuoteId = tempItem.SalesQuoteId,
                TempId = temp.TempSalesQuoteId
            };
            return Uow.TempSalesQuotes.GetList(req)?.FirstOrDefault() ?? tempItem;
        }

        public TempSalesQuoteItem Update(TempSalesQuoteItem tempItem)
        {
            var existing = Uow.TempSalesQuotes.GetById(tempItem.TempSalesQuoteId);

            if (existing != null)
            {
                if (tempItem.IsUnitChange)
                {
                    var resolvedUnit = _itemUnitService.ResolveKeyboxUnit(existing.ItemId ?? 0, tempItem.Unit);

                    if (resolvedUnit != null)
                    {
                        existing.ItemUnitId = resolvedUnit.ItemUnitId;
                        existing.Unit = resolvedUnit.Unit;
                        existing.FactorToBase = resolvedUnit.FactorToBase;

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

                existing.OrdQty = tempItem.OrdQty;
                existing.UnitPrice = tempItem.UnitPrice;
                existing.Notes = tempItem.Notes;
                existing.IsTaxable = tempItem.IsTaxable;
                existing.IsStrike = tempItem.IsStrike;

                if (existing.LineId.HasValue)
                    existing.ChangeStatus = "U";

                Uow.TempSalesQuotes.Update(existing);
                Uow.Commit();

                tempItem.InjectFrom(existing);
                tempItem.Unit = existing.Unit;
                tempItem.ItemUnitId = existing.ItemUnitId;
                tempItem.OrdQty = existing.OrdQty;
            }

            return tempItem;
        }

        public TempSalesQuoteItem UpdateUnit(TempSalesQuoteItem tempItem)
        {
            var existing = Uow.TempSalesQuotes.GetById(tempItem.TempSalesQuoteId);

            if (existing != null)
            {
                if (!existing.ItemId.HasValue)
                    throw new InvalidOperationException("ItemId is required to update unit.");

                var itemUnit = _itemUnitService.GetNextUnit(existing.ItemId.Value, existing.Unit);
                var itemPrice = _itemUnitService.GetItemPriceByCustomer(existing.PayeeId, existing.ItemId.Value, itemUnit.ItemUnitId);

                existing.ItemUnitId = itemUnit.ItemUnitId;
                existing.Unit = itemUnit.Unit;
                existing.FactorToBase = itemUnit.FactorToBase;
                existing.UnitPrice = itemPrice.DefaultPrice;

                if (existing.LineId.HasValue)
                    existing.ChangeStatus = "U";

                Uow.TempSalesQuotes.Update(existing);
                Uow.Commit();

                tempItem.InjectFrom(existing);
                tempItem.Unit = existing.Unit;
                tempItem.ItemUnitId = existing.ItemUnitId;
                tempItem.OrdQty = existing.OrdQty;
                tempItem.ListPrice = itemUnit.P1;
            }

            return tempItem;
        }

        public void Delete(int tempId)
        {
            var temp = Uow.TempSalesQuotes.GetById(tempId);

            if (temp != null)
            {
                if (temp.LineId.HasValue)
                {
                    Uow.TempSalesQuotes.Find(c => c.TempSalesQuoteId == tempId)
                        .ExecuteUpdate(setters => setters.SetProperty(x => x.ChangeStatus, x => "D"));
                }
                else
                {
                    Uow.TempSalesQuotes.Find(c => c.TempSalesQuoteId == tempId).ExecuteDelete();
                }
            }
        }

        public void Clear(TempSalesQuoteReq req)
        {
            Uow.TempSalesQuotes
                .Find(c => c.EmpId == UserContext.EmpId && c.SalesQuoteId == req.SalesQuoteId && c.PayeeId == req.PayeeId)
                .ExecuteDelete();
        }

        public IEnumerable<ItemSearch> Search(TempSalesQuoteReq req)
        {
            return Uow.TempSalesQuotes.Search(req);
        }

        public TempSalesQuoteItem? AddLine(SalesQuoteAddLineRequest req)
        {
            return Uow.TempSalesQuotes.AddLine(req);
        }
    }
}
