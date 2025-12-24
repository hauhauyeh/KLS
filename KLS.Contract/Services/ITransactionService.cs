using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Services
{
    public interface ITransactionService
    {
        PagingResponse<Transaction>? GetPagedList(TxReq txReq);

        IEnumerable<TransactionDetailList>? GetTxDetail(int txId);
    }
}
