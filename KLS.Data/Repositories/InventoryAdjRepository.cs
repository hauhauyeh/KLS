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
    public class InventoryAdjRepository : KLSRepository<InventoryAdj>, IInventoryAdjRepository
    {
        public InventoryAdjRepository(KLSDBContext dbContext) : base(dbContext)
        {

        }

        public IQueryable<InventoryAdjList> GetInventoryAdjs(InventoryAdjListReq inventoryAdjListReq)
        {
            var param = BuildInventoryAdjsParam(inventoryAdjListReq);

            return DbContext.InventoryAdjList.FromSqlRaw("[dbo].[InventoryAdj_GetAllList] @Pageno,@Pagesize,@Search,@StartDate,@EndDate,@Id,@SortField,@SortOrder,@IsCount,@TotalCount OUTPUT", param);
        }

        public int CountAllInventoryAdjs(InventoryAdjListReq inventoryAdjListReq)
        {
            inventoryAdjListReq.IsCount = true;
            var param = BuildInventoryAdjsParam(inventoryAdjListReq);

            DbContext.Database.ExecuteSqlRaw("[dbo].[InventoryAdj_GetAllList] @Pageno,@Pagesize,@Search,@StartDate,@EndDate,@Id,@SortField,@SortOrder,@IsCount,@TotalCount OUTPUT", param);

            var output = param[9] as SqlParameter;
            return Convert.ToInt32(output.Value);
        }

        private static object[] BuildInventoryAdjsParam(InventoryAdjListReq inventoryAdjListReq)
        {
            object[] param = {
                new SqlParameter("@Pageno", inventoryAdjListReq.Pageno),

                new SqlParameter("@Pagesize", inventoryAdjListReq.Pagesize),

                string.IsNullOrEmpty(inventoryAdjListReq.Search) ? new SqlParameter("@Search", DBNull.Value) : new SqlParameter("@Search", inventoryAdjListReq.Search),

                inventoryAdjListReq.StartDate.HasValue ? new SqlParameter("@StartDate", inventoryAdjListReq.StartDate) : new SqlParameter("@StartDate", DBNull.Value),

                inventoryAdjListReq.EndDate.HasValue ? new SqlParameter("@EndDate", inventoryAdjListReq.EndDate) : new SqlParameter("@EndDate", DBNull.Value),

                 inventoryAdjListReq.Id.HasValue ? new SqlParameter("@Id", inventoryAdjListReq.Id) : new SqlParameter("@Id", DBNull.Value),

                string.IsNullOrEmpty(inventoryAdjListReq.SortField) ? new SqlParameter("@SortField", DBNull.Value) : new SqlParameter("@SortField", inventoryAdjListReq.SortField),

                string.IsNullOrEmpty(inventoryAdjListReq.SortOrder) ? new SqlParameter("@SortOrder", DBNull.Value) : new SqlParameter("@SortOrder", inventoryAdjListReq.SortOrder),

                new SqlParameter("@IsCount", inventoryAdjListReq.IsCount),

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
