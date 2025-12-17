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
        PagingResponse<Transaction>? GetAllTransactions(TxReq txReq);

        //IEnumerable<TransactionDetail>? GetTxDetail(int txId);

        ICollection<TransactionDetailList>? GetTxDetail(int txId);
    }
}
