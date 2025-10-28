using KLS.Contract.Interfaces;
using KLS.Data.DataContext;
using KLS.Models;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Data.Repositories
{
    public class TransactionDetailRepository : KLSRepository<TransactionDetail>, ITransactionDetailRepository
    {
        public TransactionDetailRepository(KLSDBContext dbContext) : base(dbContext)
        {
        }

        public IQueryable<TransactionDetailList> GetTxDetail(int txId)
        {
            var TxIdParam = new SqlParameter("@TxId", txId);

            return DbContext.TransactionDetailList.FromSqlRaw("[dbo].[TransactionDetail_GetById] @TxId", TxIdParam);
        }
    }
}
