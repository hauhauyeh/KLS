using KLS.Common;
using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Services
{
    public interface ITempItemQuoteService
    {
        IEnumerable<TempItemQuoteList>? GetList(TempItemQuoteReq tempReq);

        TempItemQuoteList Create(TempItemQuoteList tempQuote);

        TempItemQuoteList Update(TempItemQuoteList tempQuote);

        void Delete(int tempId);

        void Clear(int payeeId);
    }
}
