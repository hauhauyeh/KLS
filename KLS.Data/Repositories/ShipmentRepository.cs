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
    public class ShipmentRepository : KLSRepository<Shipment>, IShipmentRepository
    {
        public ShipmentRepository(KLSDBContext dbContext) : base(dbContext)
        {
        }

        public IQueryable<ShipmentList> GetPagedList(ShipmentListReq shipmentListReq)
        {
            var param = BuildPagedList(shipmentListReq);

            return DbContext.ShipmentList.FromSqlRaw("[dbo].[Shipment_GetAllList] @Pageno,@Pagesize,@Search,@StartDate,@EndDate,@PayeeId,@Filterby,@SortField,@SortOrder,@IsCount,@TotalCount OUTPUT", param);
        }

        public int Count(ShipmentListReq shipmentListReq)
        {
            shipmentListReq.IsCount = true;
            var param = BuildPagedList(shipmentListReq);

            DbContext.Database.ExecuteSqlRaw("[dbo].[Shipment_GetAllList] @Pageno,@Pagesize,@Search,@StartDate,@EndDate,@PayeeId,@Filterby,@SortField,@SortOrder,@IsCount,@TotalCount OUTPUT", param);

            var output = param[10] as SqlParameter;
            return Convert.ToInt32(output.Value);
        }

        public void Allocation(int purchaseId)
        {
            var PurchaseIdParam = new SqlParameter("@PurchaseId", purchaseId);

            DbContext.Database.ExecuteSqlRaw("[Purchase_Allocation] @PurchaseId", PurchaseIdParam);
        }

        public void UnAllocation(int shipmentPurchaseId)
        {
            var ShipmentPurchaseIdParam = new SqlParameter("@ShipmentPurchaseId", shipmentPurchaseId);

            DbContext.Database.ExecuteSqlRaw("[Shipment_UnAllocation] @ShipmentPurchaseId", ShipmentPurchaseIdParam);
        }

        public void Delete(int shipmentId)
        {
            var ShipmentIdParam = new SqlParameter("@ShipmentId", shipmentId);

            DbContext.Database.ExecuteSqlRaw("[Shipment_Delete] @ShipmentId", ShipmentIdParam);
        }

        public void GenerateBill(int shipmentId)
        {
            var ShipmentIdParam = new SqlParameter("@ShipmentId", shipmentId);

            DbContext.Database.ExecuteSqlRaw("[Shipment_GenerateBill] @ShipmentId", ShipmentIdParam);
        }

        public void UpdateCharges(int shipmentId)
        {
            var ShipmentIdParam = new SqlParameter("@ShipmentId", shipmentId);

            DbContext.Database.ExecuteSqlRaw("[Shipment_Update] @ShipmentId", ShipmentIdParam);
        }

        public void AssignShipment(POCopyToBillReq copyToBillReq)
        {
            var PurchaseIdParam = new SqlParameter("@PurchaseId", copyToBillReq.PurchaseId);

            var ShipmentIdsParam = (!string.IsNullOrEmpty(copyToBillReq.ShipmentIds))
                ? new SqlParameter("@ShipmentIds", copyToBillReq.ShipmentIds)
                : new SqlParameter("@ShipmentIds", DBNull.Value);

            DbContext.Database.ExecuteSqlRaw("[Shipment_Assign] @PurchaseId,@ShipmentIds", PurchaseIdParam, ShipmentIdsParam);
        }

        private static object[] BuildPagedList(ShipmentListReq shipmentListReq)
        {
            object[] param = {
                new SqlParameter("@Pageno", shipmentListReq.Pageno),

                new SqlParameter("@Pagesize", shipmentListReq.Pagesize),

                string.IsNullOrEmpty(shipmentListReq.Search) ? new SqlParameter("@Search", DBNull.Value) : new SqlParameter("@Search", shipmentListReq.Search),

                shipmentListReq.StartDate.HasValue ? new SqlParameter("@StartDate", shipmentListReq.StartDate) : new SqlParameter("@StartDate", DBNull.Value),

                shipmentListReq.EndDate.HasValue ? new SqlParameter("@EndDate", shipmentListReq.EndDate) : new SqlParameter("@EndDate", DBNull.Value),

                shipmentListReq.PayeeId.HasValue ? new SqlParameter("@PayeeId", shipmentListReq.PayeeId) : new SqlParameter("@PayeeId", DBNull.Value),

                string.IsNullOrEmpty(shipmentListReq.Filterby) ? new SqlParameter("@Filterby", DBNull.Value) : new SqlParameter("@Filterby", shipmentListReq.Filterby),

                string.IsNullOrEmpty(shipmentListReq.SortField) ? new SqlParameter("@SortField", DBNull.Value) : new SqlParameter("@SortField", shipmentListReq.SortField),

                string.IsNullOrEmpty(shipmentListReq.SortOrder) ? new SqlParameter("@SortOrder", DBNull.Value) : new SqlParameter("@SortOrder", shipmentListReq.SortOrder),

                new SqlParameter("@IsCount", shipmentListReq.IsCount),

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
