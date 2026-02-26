using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Models;
using Microsoft.EntityFrameworkCore;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services
{
    public class TempItemQuoteService : BaseService, ITempItemQuoteService
    {
        private readonly IItemService _itemService;
        private readonly IItemUnitService _itemUnitService;

        public TempItemQuoteService(IUnitOfWork uow, IItemService itemService, IItemUnitService itemUnitService) : base(uow)
        {
            _itemService = itemService;
            _itemUnitService = itemUnitService;
        }

        public IEnumerable<TempItemQuoteList>? GetList(TempItemQuoteReq tempReq)
        {
            return Uow.TempItemQuotes.GetList(tempReq);
        }

        public TempItemQuote? GetById(int tempId)
        {
            return Uow.TempItemQuotes.GetById(tempId);
        }

        public TempItemQuoteList GetListById(int payeeId, int tempId)
        {
            var tempReq = new TempItemQuoteReq
            {
                PayeeId = payeeId,
                TempId = tempId
            };

            return Uow.TempItemQuotes.GetList(tempReq)?.AsEnumerable().FirstOrDefault()!;
        }

        public TempItemQuoteList Create(TempItemQuoteList tempQuote)
        {
            var item = _itemService.GetBySearch(tempQuote.ItemCode);

            if (item == null)
                throw new KeyNotFoundException("Product code not found");

            if (item.Inactive)
                throw new KeyNotFoundException("This product already discontinue");

            var unit = _itemUnitService.GetSalesUnit(item.ItemId);

            var newTempQuote = new TempItemQuote
            {
                PayeeId = tempQuote.PayeeId,
                EmpId = UserContext.EmpId,
                ItemId = item.ItemId,
                ItemUnitId = tempQuote.ItemUnitId > 0 ? tempQuote.ItemUnitId : unit.ItemUnitId
            };

            if (Exists(newTempQuote))
                throw new KeyNotFoundException("Item already exists");

            Uow.TempItemQuotes.Add(newTempQuote);
            Uow.Commit();

            return GetListById(newTempQuote.PayeeId, newTempQuote.TempQuoteId);
        }

        public TempItemQuoteList Update(TempItemQuoteList tempQuote)
        {
            var existing = GetById(tempQuote.TempQuoteId);

            if (existing != null)
            {
                existing.TargetPrice = tempQuote.TargetPrice;
                existing.NewPrice = tempQuote.NewPrice;
                existing.IsFixed = tempQuote.IsFixed;

                var basePrice = (tempQuote.IsBaseToRecentCost ? tempQuote.RecentCost : tempQuote.P1) ?? 0m;

                decimal? markup = null;
                decimal? finalPrice = tempQuote.FinalPriceUpdate;

                if (finalPrice.HasValue && finalPrice != 0 && basePrice != 0)
                    markup = Utilities.Rounding((finalPrice - basePrice) / basePrice, 4);

                existing.MarkupPercent = markup;

                if (tempQuote.IsFixed)
                    existing.TargetPrice = finalPrice;
                else
                    existing.TargetPrice = null;

                Uow.TempItemQuotes.Update(existing);
                Uow.Commit();
            }

            return GetListById(existing.PayeeId, existing.TempQuoteId);
        }

        public bool Exists(TempItemQuote tempQuote)
        {
            return Uow.TempItemQuotes.Exists(c => c.ItemId == tempQuote.ItemId && c.PayeeId == tempQuote.PayeeId && c.EmpId == UserContext.EmpId);
        }

        public void Delete(int tempId)
        {
            Uow.TempItemQuotes.Find(c => c.TempQuoteId == tempId).ExecuteDelete();
        }

        public void Clear(int payeeId)
        {
            Uow.TempItemQuotes.Find(c => c.EmpId == UserContext.EmpId && c.PayeeId == payeeId).ExecuteDelete();
        }
    }
}
