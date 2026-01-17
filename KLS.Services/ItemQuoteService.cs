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
    }
}
