using KLS.Contract.Interfaces;
using KLS.Data.DataContext;
using KLS.Models;
using KLS.Models.Deposit;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Org.BouncyCastle.Ocsp;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Data.Repositories
{
    public class TransferFundRepository : KLSRepository<TransferFund>, ITransferFundRepository
    {
        public TransferFundRepository(KLSDBContext dbContext) : base(dbContext)
        {
        }

        public IQueryable<TransferFundList> GetAllTransferFunds(TFReq tFReq)
        {
            var PagenoParam = new SqlParameter("@Pageno", tFReq.Pageno);

            var PagesizeParam = new SqlParameter("@Pagesize", tFReq.Pagesize);

            var SearchParam = (!string.IsNullOrEmpty(tFReq.Search)) ? new SqlParameter("@Search", tFReq.Search) : new SqlParameter("@Search", DBNull.Value);

            var StartDateParam = tFReq.StartDate.HasValue ? new SqlParameter("@StartDate", tFReq.StartDate) : new SqlParameter("@StartDate", DBNull.Value);

            var EndDateParam = tFReq.EndDate.HasValue ? new SqlParameter("@EndDate", tFReq.EndDate) : new SqlParameter("@EndDate", DBNull.Value);

            var TFIdParam = tFReq.Id.HasValue ? new SqlParameter("@TFId", tFReq.Id) : new SqlParameter("@TFId", DBNull.Value);

            var IsCountParam = new SqlParameter("@IsCount", tFReq.IsCount);

            return DbContext.TransferFundList.FromSqlRaw("[dbo].[TransferFund_GetAllList] @Pageno,@Pagesize,@Search,@StartDate,@EndDate,@TFId,@IsCount", PagenoParam, PagesizeParam, SearchParam, StartDateParam, EndDateParam, TFIdParam, IsCountParam);
        }

        public int SaveTransferFund(TransferFund tf)
        {
            var TFIdParam = new SqlParameter("@TFId", tf.TFId);

            var TFDateParam = tf.TFDate.HasValue ? new SqlParameter("@TFDate", tf.TFDate) : new SqlParameter("@TFDate", DBNull.Value);

            var FromAccountParam = (!string.IsNullOrEmpty(tf.FromAccount)) ? new SqlParameter("@FromAccount", tf.FromAccount) : new SqlParameter("@FromAccount", DBNull.Value);

            var ToAccountParam = (!string.IsNullOrEmpty(tf.ToAccount)) ? new SqlParameter("@ToAccount", tf.ToAccount) : new SqlParameter("@ToAccount", DBNull.Value);

            var RefNumParam = (!string.IsNullOrEmpty(tf.RefNum)) ? new SqlParameter("@RefNum", tf.RefNum) : new SqlParameter("@RefNum", DBNull.Value);

            var TransferAmountParam = tf.TransferAmount.HasValue ? new SqlParameter("@TransferAmount", tf.TransferAmount) : new SqlParameter("@TransferAmount", DBNull.Value);

            var NotesParam = (!string.IsNullOrEmpty(tf.Notes)) ? new SqlParameter("@Notes", tf.Notes) : new SqlParameter("@Notes", DBNull.Value);

            var NewTFId = new SqlParameter()
            {
                ParameterName = "@NewTFId",
                Direction = System.Data.ParameterDirection.Output,
                SqlDbType = System.Data.SqlDbType.Int
            };

            DbContext.Database.ExecuteSqlRaw("[dbo].[TransferFund_Insert] @TFId,@TFDate,@FromAccount,@ToAccount,@RefNum,@TransferAmount,@Notes,@NewTFId OUTPUT", TFIdParam, TFDateParam, FromAccountParam, ToAccountParam, RefNumParam, TransferAmountParam, NotesParam, NewTFId);

            return Convert.ToInt32(NewTFId.Value);
        }


        public IEnumerable<DepositList> GetAllDeposits(DepositReq depositReq)
        {
            var param = BuildDepositParam(depositReq);

            return DbContext.DepositList.FromSqlRaw("[dbo].[Deposit_GetAllList] @Pageno,@Pagesize,@Search,@StartDate,@EndDate,@ToAccount,@Filterby,@IsCount,@TotalCount OUTPUT", param);
        }

        public int CountAllDeposits(DepositReq depositReq)
        {
            depositReq.IsCount = true;
            var param = BuildDepositParam(depositReq);

            DbContext.Database.ExecuteSqlRaw("[dbo].[Deposit_GetAllList] @Pageno,@Pagesize,@Search,@StartDate,@EndDate,@ToAccount,@Filterby,@IsCount,@TotalCount OUTPUT", param);

            var output = param[8] as SqlParameter;
            return Convert.ToInt32(output.Value);
        }

        private object[] BuildDepositParam(DepositReq depositReq)
        {
            object[] param = {
                new SqlParameter("@Pageno", depositReq.Pageno),
                new SqlParameter("@Pagesize", depositReq.Pagesize),
                (!string.IsNullOrEmpty(depositReq.Search)) ? new SqlParameter("@Search", depositReq.Search) : new SqlParameter("@Search", DBNull.Value),
                depositReq.StartDate.HasValue ? new SqlParameter("@StartDate", depositReq.StartDate) : new SqlParameter("@StartDate", DBNull.Value),
                depositReq.EndDate.HasValue ? new SqlParameter("@EndDate", depositReq.EndDate) : new SqlParameter("@EndDate", DBNull.Value),
                (!string.IsNullOrEmpty(depositReq.ToAccount)) ? new SqlParameter("@ToAccount", depositReq.ToAccount) : new SqlParameter("@ToAccount", DBNull.Value),
                (!string.IsNullOrEmpty(depositReq.Filterby)) ? new SqlParameter("@Filterby", depositReq.Filterby) : new SqlParameter("@Filterby", DBNull.Value),
                new SqlParameter("@IsCount", depositReq.IsCount),
                new SqlParameter()
                {
                    ParameterName = "@TotalCount",
                    Direction = System.Data.ParameterDirection.Output,
                    SqlDbType = System.Data.SqlDbType.Int
                }
            };

            return param;
        }
    }
}
