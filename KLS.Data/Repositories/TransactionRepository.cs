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
    public class TransactionRepository : KLSRepository<Transaction>, ITransactionRepository
    {
        public TransactionRepository(KLSDBContext dbContext) : base(dbContext)
        {
        }

        public IQueryable<Transaction> GetPagedList(TxReq txReq)
        {
            var param = BuildParam(txReq);

            return DbContext.Transactions.FromSqlRaw("[dbo].[Transaction_GetAllList] @Pageno,@Pagesize,@Search,@StartDate,@EndDate,@DocType,@Filterby,@SortField,@SortOrder,@IsCount,@TotalCount OUTPUT", param);
        }

        public int Count(TxReq txReq)
        {
            txReq.IsCount = true;
            var param = BuildParam(txReq);

            DbContext.Database.ExecuteSqlRaw("[dbo].[Transaction_GetAllList] @Pageno,@Pagesize,@Search,@StartDate,@EndDate,@DocType,@Filterby,@SortField,@SortOrder,@IsCount,@TotalCount OUTPUT", param);

            var output = param[10] as SqlParameter;
            return Convert.ToInt32(output.Value);
        }

        private static object[] BuildParam(TxReq txReq)
        {
            object[] param = {
                new SqlParameter("@Pageno", txReq.Pageno),

                new SqlParameter("@Pagesize", txReq.Pagesize),

                (!string.IsNullOrEmpty(txReq.Search)) ? new SqlParameter("@Search", txReq.Search) : new SqlParameter("@Search", DBNull.Value),

                txReq.StartDate.HasValue ? new SqlParameter("@StartDate", txReq.StartDate) : new SqlParameter("@StartDate", DBNull.Value),

                txReq.EndDate.HasValue ? new SqlParameter("@EndDate", txReq.EndDate) : new SqlParameter("@EndDate", DBNull.Value),

                (!string.IsNullOrEmpty(txReq.DocType)) ? new SqlParameter("@DocType", txReq.DocType) : new SqlParameter("@DocType", DBNull.Value),

                (!string.IsNullOrEmpty(txReq.Filterby)) ? new SqlParameter("@Filterby", txReq.Filterby) : new SqlParameter("@Filterby", DBNull.Value),

                string.IsNullOrEmpty(txReq.SortField) ? new SqlParameter("@SortField", DBNull.Value) : new SqlParameter("@SortField", txReq.SortField),

                string.IsNullOrEmpty(txReq.SortOrder) ? new SqlParameter("@SortOrder", DBNull.Value) : new SqlParameter("@SortOrder", txReq.SortOrder),

                new SqlParameter("@IsCount", txReq.IsCount),

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
