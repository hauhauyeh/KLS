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

        public PagingResponse<Transaction>? GetAllTransactions(TxReq txReq)
        {
            var list = Uow.Transactions.GetAllTransactions(txReq).ToList();

            var totalRecords = Uow.Transactions.CountAllTransactions(txReq);

            return new PagingResponse<Transaction>(totalRecords, txReq.Pageno, txReq.Pagesize)
            {
                RowData = list,
            };
        }

        //public IEnumerable<TransactionDetail>? GetTxDetail(int txId)
        //{
        //    return Uow.TransactionDetails.Find(c => c.TxId == txId).OrderBy(c => c.TxDetailId);
        //}

        public ICollection<TransactionDetailList>? GetTxDetail(int txId)
        {
            return Uow.TransactionDetails.GetTxDetail(txId).ToList();
        }
    }
}
