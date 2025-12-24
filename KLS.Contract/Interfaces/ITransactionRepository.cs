using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Interfaces
{
    public interface ITransactionRepository : IRepository<Transaction>
    {
        IQueryable<Transaction> GetPagedList(TxReq txReq);

        int Count(TxReq txReq);
    }
}
