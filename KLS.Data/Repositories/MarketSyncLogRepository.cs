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
    public class MarketSyncLogRepository : KLSRepository<MarketSyncLog>, IMarketSyncLogRepository
    {
        public MarketSyncLogRepository(KLSDBContext dbContext) : base(dbContext)
        {
        }

        public IQueryable<MarketSyncLogList> GetPagedList(MarketSyncLogListReq req)
        {
            var param = BuildPagedList(req);
            return DbContext.MarketSyncLogList.FromSqlRaw(
                "[dbo].[MarketSyncLog_GetAllList] @Pageno,@Pagesize,@Search,@StartDate,@EndDate,@MarketAccountId,@SyncType,@Success,@SortField,@SortOrder,@IsCount,@TotalCount OUTPUT", param);
        }

        public int Count(MarketSyncLogListReq req)
        {
            req.IsCount = true;
            var param = BuildPagedList(req);
            DbContext.Database.ExecuteSqlRaw(
                "[dbo].[MarketSyncLog_GetAllList] @Pageno,@Pagesize,@Search,@StartDate,@EndDate,@MarketAccountId,@SyncType,@Success,@SortField,@SortOrder,@IsCount,@TotalCount OUTPUT", param);
            var output = param[11] as SqlParameter;
            return Convert.ToInt32(output?.Value);
        }

        private static object[] BuildPagedList(MarketSyncLogListReq req)
        {
            object[] param = {
                new SqlParameter("@Pageno", req.Pageno),
                new SqlParameter("@Pagesize", req.Pagesize),
                string.IsNullOrEmpty(req.Search) ? new SqlParameter("@Search", DBNull.Value) : new SqlParameter("@Search", req.Search),
                req.StartDate.HasValue ? new SqlParameter("@StartDate", req.StartDate) : new SqlParameter("@StartDate", DBNull.Value),
                req.EndDate.HasValue ? new SqlParameter("@EndDate", req.EndDate) : new SqlParameter("@EndDate", DBNull.Value),
                req.MarketAccountId.HasValue && req.MarketAccountId.Value > 0 ? new SqlParameter("@MarketAccountId", req.MarketAccountId) : new SqlParameter("@MarketAccountId", DBNull.Value),
                string.IsNullOrEmpty(req.SyncType) ? new SqlParameter("@SyncType", DBNull.Value) : new SqlParameter("@SyncType", req.SyncType),
                req.Success.HasValue ? new SqlParameter("@Success", req.Success) : new SqlParameter("@Success", DBNull.Value),
                string.IsNullOrEmpty(req.SortField) ? new SqlParameter("@SortField", DBNull.Value) : new SqlParameter("@SortField", req.SortField),
                string.IsNullOrEmpty(req.SortOrder) ? new SqlParameter("@SortOrder", DBNull.Value) : new SqlParameter("@SortOrder", req.SortOrder),
                new SqlParameter("@IsCount", req.IsCount),
                new SqlParameter("@TotalCount", SqlDbType.Int) { Direction = ParameterDirection.Output }
            };
            return param;
        }
    }
}
