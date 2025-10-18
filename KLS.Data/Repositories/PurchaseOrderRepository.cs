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
    public class PurchaseOrderRepository : KLSRepository<PurchaseOrder>, IPurchaseOrderRepository
    {
        public PurchaseOrderRepository(KLSDBContext dbContext) : base(dbContext)
        {

        }

        public IQueryable<PurchaseOrderList> GetPurchaseOrders(PurchaseOrderReq purchaseOrderReq)
        {
            var param = BuildPurchaseOrdersParam(purchaseOrderReq);

            return DbContext.PurchaseOrderList.FromSqlRaw("[dbo].[PurchaseOrder_GetAllList] @Pageno,@Pagesize,@Search,@StartDate,@EndDate,@PayeeId,@Filterby,@SortField,@SortOrder,@IsCount,@TotalCount OUTPUT", param);
        }

        public int CountAllPurchaseOrders(PurchaseOrderReq purchaseOrderReq)
        {
            purchaseOrderReq.IsCount = true;
            var param = BuildPurchaseOrdersParam(purchaseOrderReq);

            DbContext.Database.ExecuteSqlRaw("[dbo].[PurchaseOrder_GetAllList] @Pageno,@Pagesize,@Search,@StartDate,@EndDate,@PayeeId,@Filterby,@SortField,@SortOrder,@IsCount,@TotalCount OUTPUT", param);

            var output = param[10] as SqlParameter;
            return Convert.ToInt32(output.Value);
        }

        private static object[] BuildPurchaseOrdersParam(PurchaseOrderReq purchaseOrderReq)
        {
            object[] param = {
                new SqlParameter("@Pageno", purchaseOrderReq.Pageno),

                new SqlParameter("@Pagesize", purchaseOrderReq.Pagesize),

                string.IsNullOrEmpty(purchaseOrderReq.Search) ? new SqlParameter("@Search", DBNull.Value) : new SqlParameter("@Search", purchaseOrderReq.Search),

                purchaseOrderReq.StartDate.HasValue ? new SqlParameter("@StartDate", purchaseOrderReq.StartDate) : new SqlParameter("@StartDate", DBNull.Value),

                purchaseOrderReq.EndDate.HasValue ? new SqlParameter("@EndDate", purchaseOrderReq.EndDate) : new SqlParameter("@EndDate", DBNull.Value),

                 purchaseOrderReq.PayeeId.HasValue ? new SqlParameter("@PayeeId", purchaseOrderReq.PayeeId) : new SqlParameter("@PayeeId", DBNull.Value),

                string.IsNullOrEmpty(purchaseOrderReq.Filterby) ? new SqlParameter("@Filterby", DBNull.Value) : new SqlParameter("@Filterby", purchaseOrderReq.Filterby),

                string.IsNullOrEmpty(purchaseOrderReq.SortField) ? new SqlParameter("@SortField", DBNull.Value) : new SqlParameter("@SortField", purchaseOrderReq.SortField),

                string.IsNullOrEmpty(purchaseOrderReq.SortOrder) ? new SqlParameter("@SortOrder", DBNull.Value) : new SqlParameter("@SortOrder", purchaseOrderReq.SortOrder),

                new SqlParameter("@IsCount", purchaseOrderReq.IsCount),

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
