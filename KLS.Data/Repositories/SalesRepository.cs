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
    public class SalesRepository : KLSRepository<Sales>, ISalesRepository
    {
        public SalesRepository(KLSDBContext dbContext) : base(dbContext)
        {

        }

        public IQueryable<SalesList> GetPagedList(SalesListReq salesListReq)
        {
            var param = BuildSalesParam(salesListReq);

            return DbContext.SalesList.FromSqlRaw("[dbo].[Sales_GetAllList] @Pageno,@Pagesize,@Search,@StartDate,@EndDate,@PayeeId,@SortField,@SortOrder,@IsCount,@TotalCount OUTPUT", param);
        }

        public int Count(SalesListReq salesListReq)
        {
            salesListReq.IsCount = true;
            var param = BuildSalesParam(salesListReq);

            DbContext.Database.ExecuteSqlRaw("[dbo].[Sales_GetAllList] @Pageno,@Pagesize,@Search,@StartDate,@EndDate,@PayeeId,@SortField,@SortOrder,@IsCount,@TotalCount OUTPUT", param);

            var output = param[9] as SqlParameter;
            return Convert.ToInt32(output.Value);
        }

        private static object[] BuildSalesParam(SalesListReq salesListReq)
        {
            object[] param = {
                new SqlParameter("@Pageno", salesListReq.Pageno),

                new SqlParameter("@Pagesize", salesListReq.Pagesize),

                string.IsNullOrEmpty(salesListReq.Search) ? new SqlParameter("@Search", DBNull.Value) : new SqlParameter("@Search", salesListReq.Search),

                salesListReq.StartDate.HasValue ? new SqlParameter("@StartDate", salesListReq.StartDate) : new SqlParameter("@StartDate", DBNull.Value),

                salesListReq.EndDate.HasValue ? new SqlParameter("@EndDate", salesListReq.EndDate) : new SqlParameter("@EndDate", DBNull.Value),

                 salesListReq.PayeeId.HasValue ? new SqlParameter("@PayeeId", salesListReq.PayeeId) : new SqlParameter("@PayeeId", DBNull.Value),

                //string.IsNullOrEmpty(salesListReq.Filterby) ? new SqlParameter("@Filterby", DBNull.Value) : new SqlParameter("@Filterby", salesListReq.Filterby),

                string.IsNullOrEmpty(salesListReq.SortField) ? new SqlParameter("@SortField", DBNull.Value) : new SqlParameter("@SortField", salesListReq.SortField),

                string.IsNullOrEmpty(salesListReq.SortOrder) ? new SqlParameter("@SortOrder", DBNull.Value) : new SqlParameter("@SortOrder", salesListReq.SortOrder),

                new SqlParameter("@IsCount", salesListReq.IsCount),

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