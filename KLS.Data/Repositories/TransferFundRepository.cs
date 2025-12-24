using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Data.DataContext;
using KLS.Models;
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

        public IQueryable<TransferFundList> GetPagedTransferFunds(TFReq tFReq)
        {
            var param = BuildTransferFundParam(tFReq);

            return DbContext.TransferFundList.FromSqlRaw("[dbo].[TransferFund_GetAllList] @Pageno,@Pagesize,@Search,@StartDate,@EndDate,@TFId,@SortField,@SortOrder,@IsCount,@TotalCount OUTPUT", param);
        }

        public int CountTransferFunds(TFReq tFReq)
        {
            tFReq.IsCount = true;
            var param = BuildTransferFundParam(tFReq);

            DbContext.Database.ExecuteSqlRaw("[dbo].[TransferFund_GetAllList] @Pageno,@Pagesize,@Search,@StartDate,@EndDate,@TFId,@SortField,@SortOrder,@IsCount,@TotalCount OUTPUT", param);

            var output = param[9] as SqlParameter;
            return Convert.ToInt32(output.Value);
        }

        private object[] BuildTransferFundParam(TFReq tFReq)
        {
            object[] param = {
                new SqlParameter("@Pageno", tFReq.Pageno),

                new SqlParameter("@Pagesize", tFReq.Pagesize),

                (!string.IsNullOrEmpty(tFReq.Search)) ? new SqlParameter("@Search", tFReq.Search) : new SqlParameter("@Search", DBNull.Value),

                tFReq.StartDate.HasValue ? new SqlParameter("@StartDate", tFReq.StartDate) : new SqlParameter("@StartDate", DBNull.Value),

                tFReq.EndDate.HasValue ? new SqlParameter("@EndDate", tFReq.EndDate) : new SqlParameter("@EndDate", DBNull.Value),

                tFReq.Id.HasValue ? new SqlParameter("@TFId", tFReq.Id) : new SqlParameter("@TFId", DBNull.Value),

                string.IsNullOrEmpty(tFReq.SortField) ? new SqlParameter("@SortField", DBNull.Value) : new SqlParameter("@SortField", tFReq.SortField),

                string.IsNullOrEmpty(tFReq.SortOrder) ? new SqlParameter("@SortOrder", DBNull.Value) : new SqlParameter("@SortOrder", tFReq.SortOrder),

                new SqlParameter("@IsCount", tFReq.IsCount),

                new SqlParameter()
                {
                    ParameterName = "@TotalCount",
                    Direction = System.Data.ParameterDirection.Output,
                    SqlDbType = System.Data.SqlDbType.Int
                }
            };

            return param;
        }

        public int SaveTransferFund(TransferFund tf)
        {
            var TFIdParam = new SqlParameter("@TFId", tf.TFId);

            var TFDateParam = tf.TFDate.HasValue ? new SqlParameter("@TFDate", tf.TFDate) : new SqlParameter("@TFDate", DBNull.Value);

            var FromAccountIdParam = tf.FromAccountId.HasValue ? new SqlParameter("@FromAccountId", tf.FromAccountId) : new SqlParameter("@FromAccountId", DBNull.Value);

            var ToAccountIdParam = tf.ToAccountId.HasValue ? new SqlParameter("@ToAccountId", tf.ToAccountId) : new SqlParameter("@ToAccountId", DBNull.Value);

            var ReferenceIdParam = (!string.IsNullOrEmpty(tf.ReferenceId)) ? new SqlParameter("@ReferenceId", tf.ReferenceId) : new SqlParameter("@ReferenceId", DBNull.Value);

            var TransferAmountParam = tf.TransferAmount.HasValue ? new SqlParameter("@TransferAmount", tf.TransferAmount) : new SqlParameter("@TransferAmount", DBNull.Value);

            var NotesParam = (!string.IsNullOrEmpty(tf.Notes)) ? new SqlParameter("@Notes", tf.Notes) : new SqlParameter("@Notes", DBNull.Value);

            var NewTFId = new SqlParameter()
            {
                ParameterName = "@NewTFId",
                Direction = System.Data.ParameterDirection.Output,
                SqlDbType = System.Data.SqlDbType.Int
            };

            DbContext.Database.ExecuteSqlRaw("[dbo].[TransferFund_Insert] @TFId,@TFDate,@FromAccountId,@ToAccountId,@ReferenceId,@TransferAmount,@Notes,@NewTFId OUTPUT", TFIdParam, TFDateParam, FromAccountIdParam, ToAccountIdParam, ReferenceIdParam, TransferAmountParam, NotesParam, NewTFId);

            return Convert.ToInt32(NewTFId.Value);
        }


        public IQueryable<DepositList> GetPagedDeposits(DepositReq depositReq)
        {
            var param = BuildDepositParam(depositReq);

            return DbContext.DepositList.FromSqlRaw("[dbo].[Deposit_GetAllList] @Pageno,@Pagesize,@Search,@StartDate,@EndDate,@ToAccountId,@Filterby,@SortField,@SortOrder,@IsCount,@TotalCount OUTPUT", param);
        }

        public int CountDeposits(DepositReq depositReq)
        {
            depositReq.IsCount = true;
            var param = BuildDepositParam(depositReq);

            DbContext.Database.ExecuteSqlRaw("[dbo].[Deposit_GetAllList] @Pageno,@Pagesize,@Search,@StartDate,@EndDate,@ToAccountId,@Filterby,@SortField,@SortOrder,@IsCount,@TotalCount OUTPUT", param);

            var output = param[10] as SqlParameter;
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

                depositReq.ToAccountId.HasValue ? new SqlParameter("@ToAccountId", depositReq.ToAccountId) : new SqlParameter("@ToAccountId", DBNull.Value),

                (!string.IsNullOrEmpty(depositReq.Filterby)) ? new SqlParameter("@Filterby", depositReq.Filterby) : new SqlParameter("@Filterby", DBNull.Value),

                string.IsNullOrEmpty(depositReq.SortField) ? new SqlParameter("@SortField", DBNull.Value) : new SqlParameter("@SortField", depositReq.SortField),

                string.IsNullOrEmpty(depositReq.SortOrder) ? new SqlParameter("@SortOrder", DBNull.Value) : new SqlParameter("@SortOrder", depositReq.SortOrder),

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

        public int SaveDeposit(TransferFund tf)
        {
            var TFIdParam = new SqlParameter("@TFId", tf.TFId);

            var TFDateParam = tf.TFDate.HasValue ? new SqlParameter("@TFDate", tf.TFDate) : new SqlParameter("@TFDate", DBNull.Value);

            //var FromAccountIdParam = tf.FromAccountId.HasValue ? new SqlParameter("@FromAccountId", tf.FromAccountId) : new SqlParameter("@FromAccountId", DBNull.Value);

            var ToAccountIdParam = tf.ToAccountId.HasValue ? new SqlParameter("@ToAccountId", tf.ToAccountId) : new SqlParameter("@FromAccToAccountIdountId", DBNull.Value);

            var TransferAmountParam = tf.TransferAmount.HasValue ? new SqlParameter("@TransferAmount", tf.TransferAmount) : new SqlParameter("@TransferAmount", DBNull.Value);

            var CashbackAccountIdParam = tf.CashbackAccountId.HasValue ? new SqlParameter("@CashbackAccountId", tf.CashbackAccountId) : new SqlParameter("@CashbackAccountId", DBNull.Value);

            var CashbackAmountParam = tf.CashbackAmount.HasValue ? new SqlParameter("@CashbackAmount", tf.CashbackAmount) : new SqlParameter("@CashbackAmount", DBNull.Value);

            var CCFeeAmountParam = tf.CCFeeAmount.HasValue ? new SqlParameter("@CCFeeAmount", tf.CCFeeAmount) : new SqlParameter("@CCFeeAmount", DBNull.Value);

            var RoundingOffParam = tf.RoundingOff.HasValue ? new SqlParameter("@RoundingOff", tf.RoundingOff) : new SqlParameter("@RoundingOff", DBNull.Value);

            var EmpIdParam = new SqlParameter("@EmpId", UserContext.EmpId);

            var NewTFId = new SqlParameter()
            {
                ParameterName = "@NewTFId",
                Direction = System.Data.ParameterDirection.Output,
                SqlDbType = System.Data.SqlDbType.Int
            };

            DbContext.Database.ExecuteSqlRaw("[dbo].[Deposit_Insert] @TFId,@TFDate,@ToAccountId,@TransferAmount,@CashbackAccountId,@CashbackAmount,@CCFeeAmount,@RoundingOff,@EmpId,@NewTFId OUTPUT", TFIdParam, TFDateParam, ToAccountIdParam, TransferAmountParam, CashbackAccountIdParam, CashbackAmountParam, CCFeeAmountParam, RoundingOffParam, EmpIdParam, NewTFId);

            return Convert.ToInt32(NewTFId.Value);
        }

        public IQueryable<TempDepositList>? InjectDeposit(int tfId)
        {
            var TFIdParam = new SqlParameter("@TFId", tfId);

            var EmpIdParam = new SqlParameter("@EmpId", UserContext.EmpId);

            //var PmtMethodParam = string.IsNullOrEmpty(injectReq.PaymentMethod) ? new SqlParameter("@PaymentMethod", DBNull.Value) : new SqlParameter("@PaymentMethod", cart.PmtMethod);

            //var StartDateParam = cart.StartDate.HasValue ? new SqlParameter("@StartDate", cart.StartDate) : new SqlParameter("@StartDate", DBNull.Value);

            //var EndDateParam = cart.EndDate.HasValue ? new SqlParameter("@EndDate", cart.EndDate) : new SqlParameter("@EndDate", DBNull.Value);

            return DbContext.TempDepositList.FromSqlRaw("[dbo].[Deposit_Inject] @TFId,@EmpId", TFIdParam, EmpIdParam);
        }
    }
}
