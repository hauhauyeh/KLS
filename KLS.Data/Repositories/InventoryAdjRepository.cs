using KLS.Common;
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

        public IQueryable<InventoryAdjList> GetPagedList(InventoryAdjListReq inventoryAdjListReq)
        {
            var param = BuildParam(inventoryAdjListReq);

            return DbContext.InventoryAdjList.FromSqlRaw("[dbo].[InventoryAdj_GetAllList] @Pageno,@Pagesize,@Search,@StartDate,@EndDate,@Id,@SortField,@SortOrder,@IsCount,@TotalCount OUTPUT", param);
        }

        public IEnumerable<InventoryAdjList> GetHistoryByItem(int itemId)
        {
            var itemIdParam = new SqlParameter("@ItemId", itemId);

            return DbContext.InventoryAdjList
                .FromSqlRaw("[dbo].[InventoryAdj_GetHistoryByItem] @ItemId", itemIdParam)
                .ToList();
        }

        public int Count(InventoryAdjListReq inventoryAdjListReq)
        {
            inventoryAdjListReq.IsCount = true;
            var param = BuildParam(inventoryAdjListReq);

            DbContext.Database.ExecuteSqlRaw("[dbo].[InventoryAdj_GetAllList] @Pageno,@Pagesize,@Search,@StartDate,@EndDate,@Id,@SortField,@SortOrder,@IsCount,@TotalCount OUTPUT", param);

            var output = param[9] as SqlParameter;
            return Convert.ToInt32(output.Value);
        }

        private static object[] BuildParam(InventoryAdjListReq inventoryAdjListReq)
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

        public int Save(InventoryAdj inventoryAdj)
        {
            var AdjIdParam = new SqlParameter("@AdjId", inventoryAdj.AdjId);

            var AdjDateParam = new SqlParameter("@AdjDate", inventoryAdj.AdjDate);

            var AdjTypeParam = new SqlParameter("@AdjType", inventoryAdj.AdjType);

            var OpenCloseParam = string.IsNullOrEmpty(inventoryAdj.OpenClose) ? new SqlParameter("@OpenClose", DBNull.Value) : new SqlParameter("@OpenClose", inventoryAdj.OpenClose);

            var NotesParam = string.IsNullOrEmpty(inventoryAdj.Notes) ? new SqlParameter("@Notes", DBNull.Value) : new SqlParameter("@Notes", inventoryAdj.Notes);

            var EmpIdParam = new SqlParameter("@EmpId", UserContext.EmpId);

            var NewAdjId = new SqlParameter()
            {
                ParameterName = "@NewAdjId",
                Direction = System.Data.ParameterDirection.Output,
                SqlDbType = System.Data.SqlDbType.Int
            };

            if (inventoryAdj.AdjId > 0)
            {
                DbContext.Database.ExecuteSqlRaw("[dbo].[InventoryAdj_PartialUpdate] @AdjId,@AdjDate,@AdjType,@OpenClose,@Notes,@EmpId", AdjIdParam, AdjDateParam, AdjTypeParam, OpenCloseParam, NotesParam, EmpIdParam);

                return inventoryAdj.AdjId;
            }
            else
            {
                DbContext.Database.ExecuteSqlRaw("[dbo].[InventoryAdj_Insert] @AdjId,@AdjDate,@AdjType,@OpenClose,@Notes,@EmpId,@NewAdjId OUTPUT", AdjIdParam, AdjDateParam, AdjTypeParam, OpenCloseParam, NotesParam, EmpIdParam, NewAdjId);

                return Convert.ToInt32(NewAdjId.Value);
            }
        }

        public void Inject(int adjId)
        {
            var EmpIdParam = new SqlParameter("@EmpId", UserContext.EmpId);

            var AdjIdParam = new SqlParameter("@AdjId", adjId);

            DbContext.Database.ExecuteSqlRaw("[dbo].[InventoryAdj_Inject] @EmpId,@AdjId", EmpIdParam, AdjIdParam);
        }

        public void DeleteDetail(int adjDetailId)
        {
            var AdjDetailIdParam = new SqlParameter("@AdjDetailId", adjDetailId);

            DbContext.Database.ExecuteSqlRaw("[dbo].[InventoryAdj_DeleteDetail] @AdjDetailId", AdjDetailIdParam);
        }

        public void QtyAdj(QtyAdjReq adjReq)
        {
            var AdjDateParam = new SqlParameter("@AdjDate", adjReq.AdjDate);

            var ItemIdParam = new SqlParameter("@ItemId", adjReq.ItemId);

            var OpenCloseParam = string.IsNullOrEmpty(adjReq.OpenClose) ? new SqlParameter("@OpenClose", DBNull.Value) : new SqlParameter("@OpenClose", adjReq.OpenClose);

            var NewQtyParam = new SqlParameter("@NewQty", adjReq.NewQty);

            var NewPriceParam = adjReq.NewPrice.HasValue ? new SqlParameter("@NewPrice", adjReq.NewPrice) : new SqlParameter("@NewPrice", DBNull.Value);

            var EmpIdParam = new SqlParameter("@EmpId", UserContext.EmpId);

            DbContext.Database.ExecuteSqlRaw("[dbo].[InventoryAdj_FromProduct] @AdjDate,@ItemId,@OpenClose,@NewQty,@NewPrice,@EmpId", AdjDateParam, ItemIdParam, OpenCloseParam, NewQtyParam, NewPriceParam, EmpIdParam);
        }

        public InventoryClosingDetail GetClosingQty(int itemId)
        {
            var ItemIdParam = new SqlParameter("@ItemId", itemId);

            return DbContext.InventoryClosingDetail.FromSqlRaw("[dbo].[InventoryAdj_GetTodayCloQty] @ItemId", ItemIdParam).ToList().FirstOrDefault();
        }
    }
}
