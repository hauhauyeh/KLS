using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Data.DataContext;
using KLS.Models;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using System;
using System.Collections.Generic;
using System.Data;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Data.Repositories
{
    public class MarketOrderRepository : KLSRepository<MarketOrder>, IMarketOrderRepository
    {
        public MarketOrderRepository(KLSDBContext dbContext) : base(dbContext)
        {
        }

        public IQueryable<MarketOrderList> GetPagedList(MarketOrderListReq req)
        {
            var param = BuildPagedList(req);
            return DbContext.MarketOrderList.FromSqlRaw(
                "[dbo].[MarketOrder_GetAllList] @Pageno,@Pagesize,@Search,@StartDate,@EndDate,@MarketAccountId,@OrderStatus,@ImportedToErp,@MatchFilter,@SortField,@SortOrder,@IsCount,@TotalCount OUTPUT", param);
        }

        public int Count(MarketOrderListReq req)
        {
            req.IsCount = true;
            var param = BuildPagedList(req);
            DbContext.Database.ExecuteSqlRaw(
                "[dbo].[MarketOrder_GetAllList] @Pageno,@Pagesize,@Search,@StartDate,@EndDate,@MarketAccountId,@OrderStatus,@ImportedToErp,@MatchFilter,@SortField,@SortOrder,@IsCount,@TotalCount OUTPUT", param);
            var output = param[12] as SqlParameter;
            return Convert.ToInt32(output?.Value);
        }

        private static object[] BuildPagedList(MarketOrderListReq req)
        {
            object[] param = {
                new SqlParameter("@Pageno", req.Pageno),
                new SqlParameter("@Pagesize", req.Pagesize),
                string.IsNullOrEmpty(req.Search) ? new SqlParameter("@Search", DBNull.Value) : new SqlParameter("@Search", req.Search),
                req.StartDate.HasValue ? new SqlParameter("@StartDate", req.StartDate) : new SqlParameter("@StartDate", DBNull.Value),
                req.EndDate.HasValue ? new SqlParameter("@EndDate", req.EndDate) : new SqlParameter("@EndDate", DBNull.Value),
                req.MarketAccountId.HasValue && req.MarketAccountId.Value > 0 ? new SqlParameter("@MarketAccountId", req.MarketAccountId) : new SqlParameter("@MarketAccountId", DBNull.Value),
                string.IsNullOrEmpty(req.OrderStatus) ? new SqlParameter("@OrderStatus", DBNull.Value) : new SqlParameter("@OrderStatus", req.OrderStatus),
                req.ImportedToErp.HasValue ? new SqlParameter("@ImportedToErp", req.ImportedToErp) : new SqlParameter("@ImportedToErp", DBNull.Value),
                string.IsNullOrEmpty(req.MatchFilter) ? new SqlParameter("@MatchFilter", DBNull.Value) : new SqlParameter("@MatchFilter", req.MatchFilter),
                string.IsNullOrEmpty(req.SortField) ? new SqlParameter("@SortField", DBNull.Value) : new SqlParameter("@SortField", req.SortField),
                string.IsNullOrEmpty(req.SortOrder) ? new SqlParameter("@SortOrder", DBNull.Value) : new SqlParameter("@SortOrder", req.SortOrder),
                new SqlParameter("@IsCount", req.IsCount),
                new SqlParameter("@TotalCount", SqlDbType.Int) { Direction = ParameterDirection.Output }
            };
            return param;
        }

        public int ConvertToSales(int marketAccountId, DateOnly orderDate)
        {
            var accountIdParam = new SqlParameter("@MarketAccountId", marketAccountId);
            var dateParam = new SqlParameter("@OrderDate", orderDate.ToDateTime(TimeOnly.MinValue));
            var empIdParam = new SqlParameter("@EmpId", UserContext.EmpId);
            var newSalesIdOut = new SqlParameter("@NewSalesId", SqlDbType.Int) { Direction = ParameterDirection.Output };

            DbContext.Database.ExecuteSqlRaw(
                "[MarketPlaceOrder_Convert] @MarketAccountId, @OrderDate, @EmpId, @NewSalesId OUTPUT",
                accountIdParam, dateParam, empIdParam, newSalesIdOut);

            return (int)newSalesIdOut.Value;
        }
    }
}
