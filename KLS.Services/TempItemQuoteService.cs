using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Models;
using Microsoft.EntityFrameworkCore;
using Square;
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
        private readonly ISystemSettingService _systemSettingService;

        public TempItemQuoteService(IUnitOfWork uow, IItemService itemService, IItemUnitService itemUnitService, ISystemSettingService systemSettingService) : base(uow)
        {
            _itemService = itemService;
            _itemUnitService = itemUnitService;
            _systemSettingService = systemSettingService;
        }

        public IEnumerable<TempItemQuoteList>? GetList(TempItemQuoteReq tempReq)
        {
            // 4dp Section B Phase-2 (Slice 5): materialize FIRST, then thread the active price precision into the rows.
            var priceDecimals = _systemSettingService.GetPriceDecimals();
            var rows = Uow.TempItemQuotes.GetList(tempReq)?.ToList();
            rows?.ForEach(r => r.PriceDecimals = priceDecimals);
            return rows;
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

            // 4dp Section B Phase-2 (Slice 5): thread the active price precision into the returned row.
            var row = Uow.TempItemQuotes.GetList(tempReq)?.AsEnumerable().FirstOrDefault()!;
            if (row != null) row.PriceDecimals = _systemSettingService.GetPriceDecimals();
            return row;
        }

        public IEnumerable<TempItemQuoteList> Create(TempItemQuoteList tempQuote)
        {
            var item = _itemService.GetBySearch(tempQuote.ItemCode);

            if (item == null)
                throw new KeyNotFoundException("Product code not found");

            if (item.Inactive)
                throw new KeyNotFoundException("This product already discontinue");

            var units = _itemUnitService.GetByItemId(item.ItemId);

            var insertedRows = new List<TempItemQuote>();

            foreach (var unit in units)
            {
                var row = new TempItemQuote
                {
                    PayeeId = tempQuote.PayeeId,
                    EmpId = UserContext.EmpId,
                    ItemId = item.ItemId,
                    ItemUnitId = unit.ItemUnitId
                };

                if (!Exists(row))
                {
                    var customer = Uow.Customers.GetById(tempQuote.PayeeId);

                    if (customer != null && !unit.IsBaseUnit && customer.BaseMarkup != 0)
                        row.MarkupPercent = 0;

                    Uow.TempItemQuotes.Add(row);
                    insertedRows.Add(row);
                }
            }

            if (!insertedRows.Any())
                return new List<TempItemQuoteList>();

            Uow.Commit();

            return insertedRows
                .Select(x => GetListById(x.PayeeId, x.TempQuoteId))
                .Where(x => x != null)
                .ToList();
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
                decimal? finalPrice = null;

                if (tempQuote.MarkupPercentUpdate.HasValue)
                {
                    markup = tempQuote.MarkupPercentUpdate;
                    if (basePrice != 0)
                        finalPrice = Utilities.Rounding(basePrice * (1 + markup.Value), _systemSettingService.GetPriceDecimals());
                }
                else
                {
                    finalPrice = tempQuote.FinalPriceUpdate;
                    if (finalPrice.HasValue && finalPrice != 0 && basePrice != 0)
                        markup = Utilities.Rounding((finalPrice - basePrice) / basePrice, 4);
                }

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
            return Uow.TempItemQuotes.Exists(c =>
                c.ItemId == tempQuote.ItemId
                && c.ItemUnitId == tempQuote.ItemUnitId
                && c.PayeeId == tempQuote.PayeeId
                && c.EmpId == UserContext.EmpId);
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
