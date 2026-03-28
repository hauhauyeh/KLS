using KLS.Contract.Interfaces;
using KLS.Data.DataContext;
using KLS.Data.Repositories;
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
    public class BankReconRepository : KLSRepository<BankRecon>, IBankReconRepository
    {
        public BankReconRepository(KLSDBContext dbContext) : base(dbContext)
        {

        }

        public BankReconBalance GetBalance(int bankReconId)
        {
            var param = new SqlParameter("@BankReconId", bankReconId);
            return DbContext.BankReconBalances
                .FromSqlRaw("[dbo].[BankRecon_Balance] @BankReconId", param)
                .AsNoTracking()
                .AsEnumerable()
                .First();
        }

        public IQueryable<BankTx> GetTx(int bankReconId)
        {
            var param = new SqlParameter("@BankReconId", bankReconId);
            return DbContext.BankTxs
                .FromSqlRaw("[dbo].[BankRecon_TxList] @BankReconId", param)
                .AsNoTracking();
        }

        public void UpdateBankDate(BankTx bankTx)
        {
            var txId     = new SqlParameter("@TxId", bankTx.TxId ?? (object)DBNull.Value);
            var bankDate = bankTx.BankDate.HasValue
                           ? new SqlParameter("@BankDate", bankTx.BankDate.Value)
                           : new SqlParameter("@BankDate", DBNull.Value);
            var refId    = string.IsNullOrEmpty(bankTx.ReferenceId)
                           ? new SqlParameter("@ReferenceId", DBNull.Value)
                           : new SqlParameter("@ReferenceId", bankTx.ReferenceId);
            var payeeId  = bankTx.PayeeId.HasValue
                           ? new SqlParameter("@PayeeId", bankTx.PayeeId.Value)
                           : new SqlParameter("@PayeeId", DBNull.Value);

            DbContext.Database.ExecuteSqlRaw(
                "[dbo].[Transaction_UpdateBankDate] @TxId, @BankDate, @ReferenceId, @PayeeId",
                txId, bankDate, refId, payeeId);
        }
    }
}
