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
    public class PurchaseRepository : KLSRepository<Purchase>, IPurchaseRepository
    {
        public PurchaseRepository(KLSDBContext dbContext) : base(dbContext)
        {

        }

        public IQueryable<PurchaseList> GetAllPurchase(PurchaseListReq purchaseListReq)
        {
            var param = BuildPurchaseParam(purchaseListReq);

            return DbContext.PurchaseList.FromSqlRaw("[dbo].[Purchase_GetAllList] @Pageno,@Pagesize,@Search,@StartDate,@EndDate,@PayeeId,@Filterby,@SortField,@SortOrder,@IsCount,@TotalCount OUTPUT", param);
        }

        public int CountAllPurchase(PurchaseListReq purchaseListReq)
        {
            purchaseListReq.IsCount = true;
            var param = BuildPurchaseParam(purchaseListReq);

            DbContext.Database.ExecuteSqlRaw("[dbo].[Purchase_GetAllList] @Pageno,@Pagesize,@Search,@StartDate,@EndDate,@PayeeId,@Filterby,@SortField,@SortOrder,@IsCount,@TotalCount OUTPUT", param);

            var output = param[10] as SqlParameter;
            return Convert.ToInt32(output.Value);
        }

        private static object[] BuildPurchaseParam(PurchaseListReq purchaseListReq)
        {
            object[] param = {
                new SqlParameter("@Pageno", purchaseListReq.Pageno),

                new SqlParameter("@Pagesize", purchaseListReq.Pagesize),

                string.IsNullOrEmpty(purchaseListReq.Search) ? new SqlParameter("@Search", DBNull.Value) : new SqlParameter("@Search", purchaseListReq.Search),

                purchaseListReq.StartDate.HasValue ? new SqlParameter("@StartDate", purchaseListReq.StartDate) : new SqlParameter("@StartDate", DBNull.Value),

                purchaseListReq.EndDate.HasValue ? new SqlParameter("@EndDate", purchaseListReq.EndDate) : new SqlParameter("@EndDate", DBNull.Value),

                purchaseListReq.PayeeId.HasValue ? new SqlParameter("@PayeeId", purchaseListReq.PayeeId) : new SqlParameter("@PayeeId", DBNull.Value),

                string.IsNullOrEmpty(purchaseListReq.Filterby) ? new SqlParameter("@Filterby", DBNull.Value) : new SqlParameter("@Filterby", purchaseListReq.Filterby),

                string.IsNullOrEmpty(purchaseListReq.SortField) ? new SqlParameter("@SortField", DBNull.Value) : new SqlParameter("@SortField", purchaseListReq.SortField),

                string.IsNullOrEmpty(purchaseListReq.SortOrder) ? new SqlParameter("@SortOrder", DBNull.Value) : new SqlParameter("@SortOrder", purchaseListReq.SortOrder),

                new SqlParameter("@IsCount", purchaseListReq.IsCount),

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
