using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services
{
    public class TransactionService : BaseService, ITransactionService
    {
        public TransactionService(IUnitOfWork uow) : base(uow)
        {
        }

        public PagingResponse<Transaction>? GetPagedList(TxReq txReq)
        {
            var list = Uow.Transactions.GetPagedList(txReq).ToList();

            var totalRecords = Uow.Transactions.Count(txReq);

            return new PagingResponse<Transaction>(totalRecords, txReq.Pageno, txReq.Pagesize)
            {
                RowData = list,
            };
        }

        public IEnumerable<TransactionDetailList>? GetTxDetail(int txId)
        {
            return Uow.TransactionDetails.GetTxDetail(txId).ToList();
        }
    }
}
