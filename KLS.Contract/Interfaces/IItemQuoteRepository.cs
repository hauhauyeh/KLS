using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Interfaces
{
    public interface IItemQuoteRepository : IRepository<ItemQuote>
    {
        int Build(ItemQuoteBuildReq buildReq);

        void Inject(int payeeId);

        void Save(int payeeId);
    }
}
