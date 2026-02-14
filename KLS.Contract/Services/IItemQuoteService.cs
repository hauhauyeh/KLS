using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Services
{
    public interface IItemQuoteService
    {
        int Build(ItemQuoteBuildReq buildReq);

        void Clear(int payeeId);

        void Inject(int payeeId);

        int Save(int payeeId);

        int OwnCount(int payeeId);

        IEnumerable<TargetQuotePrice> GetTargetrPrice(int itemId, string? filterby);

        ItemQuote Update(TargetQuotePrice quotePrice);

        void Delete(int itemQuoteId);
    }
}
