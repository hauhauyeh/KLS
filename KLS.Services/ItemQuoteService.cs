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
    public class ItemQuoteService : BaseService, IItemQuoteService
    {
        public ItemQuoteService(IUnitOfWork uow) : base(uow)
        {

        }

        public ItemQuote GetById(int quoteId)
        {
            return Uow.ItemQuotes.GetById(quoteId);
        }

        public int Build(ItemQuoteBuildReq buildReq)
        {
            return Uow.ItemQuotes.Build(buildReq);
        }

        public void Clear(int payeeId)
        {
            Uow.ItemQuotes.Find(c => c.PayeeId == payeeId).ExecuteDelete();
        }

        public void Inject(int payeeId)
        {
            Uow.ItemQuotes.Inject(payeeId);
        }

        public int Save(int payeeId)
        {
            Uow.ItemQuotes.Save(payeeId);

            return OwnCount(payeeId);
        }

        public int OwnCount(int payeeId)
        {
            return Uow.ItemQuotes.Find(c => c.PayeeId == payeeId).Count();
        }

        public IEnumerable<TargetQuotePrice> GetTargetrPrice(int itemId, string? filterby)
        {
            return Uow.ItemQuotes.GetTargetrPrice(itemId, filterby);
        }

        public ItemQuote Update(TargetQuotePrice quotePrice)
        {
            var existing = GetById(quotePrice.ItemQuoteId);

            if (existing != null)
            {
                existing.TargetPrice = quotePrice.TargetPrice;
                //quote.NewPrice = quotePrice.NewPrice;
                existing.IsFixed = quotePrice.IsFixed;

                var basePrice = (quotePrice.IsBaseToRecentCost ? quotePrice.RecentCost : quotePrice.P1) ?? 0m;

                decimal? markup = null;
                decimal? finalPrice = quotePrice.FinalPriceUpdate;

                if (finalPrice.HasValue && finalPrice != 0 && basePrice != 0)
                    markup = Utilities.Rounding((finalPrice - basePrice) / basePrice, 4);

                existing.MarkupPercent = markup;

                if (quotePrice.IsFixed)
                    existing.TargetPrice = finalPrice;
                else
                    existing.TargetPrice = null;

                Uow.ItemQuotes.Update(existing);
                Uow.Commit();
            }

            return existing;
        }

        public void Delete(int itemQuoteId)
        {
            Uow.ItemQuotes.Find(c => c.ItemQuoteId == itemQuoteId).ExecuteDelete();
        }
    }
}
