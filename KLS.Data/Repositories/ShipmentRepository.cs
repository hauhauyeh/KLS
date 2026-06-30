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

        public void Allocation(int purchaseId, bool refreshVolume = false)
        {
            var PurchaseIdParam = new SqlParameter("@PurchaseId", purchaseId);
            var RefreshVolumeParam = new SqlParameter("@RefreshVolume", refreshVolume);

            DbContext.Database.ExecuteSqlRaw("[Purchase_Allocation] @PurchaseId, @RefreshVolume", PurchaseIdParam, RefreshVolumeParam);
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

        public IEnumerable<AssignedPurchase>? AssignedPurchases(int shipmentId)
        {
            var ShipmentIdParam = new SqlParameter("@ShipmentId", shipmentId);

            return DbContext.AssignedPurchase.FromSqlRaw("[Shipment_AssignedPurchase] @ShipmentId", ShipmentIdParam);
        }

        public AllocationValidationResult ValidateAllocation(int purchaseId)
            => RunValidateAllocation(new SqlParameter("@PurchaseId", purchaseId));

        // 2026-06-29: shipment-scoped variant (Plan 1) — same SP, called with @ShipmentId so the
        // coverage is over all bills in the shipment (the allocation guard's scope).
        public AllocationValidationResult ValidateAllocationByShipment(int shipmentId)
            => RunValidateAllocation(new SqlParameter("@ShipmentId", shipmentId));

        // Shared runner for [Shipment_ValidateAllocation]. The SP accepts either @PurchaseId (bill
        // scope) or @ShipmentId (shipment scope); the caller passes whichever applies (the other
        // defaults to NULL in the SP). Bound by name, so parameter order is irrelevant.
        private AllocationValidationResult RunValidateAllocation(params SqlParameter[] parameters)
        {
            var result = new AllocationValidationResult();
            var conn = DbContext.Database.GetDbConnection();
            var wasClosed = conn.State != System.Data.ConnectionState.Open;

            if (wasClosed) conn.Open();
            try
            {
                using var cmd = conn.CreateCommand();
                cmd.CommandText = "[dbo].[Shipment_ValidateAllocation]";
                cmd.CommandType = System.Data.CommandType.StoredProcedure;
                cmd.Parameters.AddRange(parameters);

                using var reader = cmd.ExecuteReader();
                while (reader.Read())
                {
                    result.Methods.Add(new AllocationMethodSummary
                    {
                        Method = reader.GetString(0),
                        TotalItems = reader.GetInt32(1),
                        ItemsWithData = reader.GetInt32(2),
                        ItemsMissing = reader.GetInt32(3),
                        Coverage = reader.GetInt32(4)
                    });
                }
            }
            finally
            {
                if (wasClosed) conn.Close();
            }

            return result;
        }

        public List<AllocationMissingItem> ValidateAllocationDetail(int purchaseId, string method)
            => RunValidateAllocationDetail(method, new SqlParameter("@PurchaseId", purchaseId), new SqlParameter("@Method", method));

        // 2026-06-29: shipment-scoped variant (Plan 1) — same SP, called with @ShipmentId.
        public List<AllocationMissingItem> ValidateAllocationByShipmentDetail(int shipmentId, string method)
            => RunValidateAllocationDetail(method, new SqlParameter("@ShipmentId", shipmentId), new SqlParameter("@Method", method));

        // Shared runner for [Shipment_ValidateAllocationDetail]. Bill scope (@PurchaseId) or shipment
        // scope (@ShipmentId); @Method is always supplied. Bound by name.
        private List<AllocationMissingItem> RunValidateAllocationDetail(string method, params SqlParameter[] parameters)
        {
            var items = new List<AllocationMissingItem>();
            var conn = DbContext.Database.GetDbConnection();
            var wasClosed = conn.State != System.Data.ConnectionState.Open;

            if (wasClosed) conn.Open();
            try
            {
                using var cmd = conn.CreateCommand();
                cmd.CommandText = "[dbo].[Shipment_ValidateAllocationDetail]";
                cmd.CommandType = System.Data.CommandType.StoredProcedure;
                cmd.Parameters.AddRange(parameters);

                using var reader = cmd.ExecuteReader();
                while (reader.Read())
                {
                    items.Add(new AllocationMissingItem
                    {
                        ItemId = reader.GetInt32(0),
                        ItemCode = reader.GetString(1),
                        ItemName = reader.GetString(2),
                        MissingField = reader.GetString(3),
                        Method = method
                    });
                }
            }
            finally
            {
                if (wasClosed) conn.Close();
            }

            return items;
        }

        public IEnumerable<AllocationResultItem> AllocationResult(int purchaseId)
        {
            var results = new List<AllocationResultItem>();

            var sql = @"
                SELECT sc.ChargeType, sc.AllocationMethod AS RequestedMethod, sa.AllocationMethod AS UsedMethod,
                       COUNT(*) AS ItemCount,
                       SUM(CASE WHEN sa.AllocationMethod = 'BY_VALUE_FALLBACK' THEN 1 ELSE 0 END) AS FallbackCount
                FROM dbo.ShipmentAllocation sa
                JOIN dbo.ShipmentCharge sc ON sa.ChargeId = sc.ChargeId
                JOIN dbo.ShipmentPurchase sp ON sc.ShipmentId = sp.ShipmentId
                WHERE sp.PurchaseId = @PurchaseId
                GROUP BY sc.ChargeType, sc.AllocationMethod, sa.AllocationMethod";

            var conn = DbContext.Database.GetDbConnection();
            var wasClosed = conn.State != System.Data.ConnectionState.Open;

            if (wasClosed) conn.Open();
            try
            {
                using var cmd = conn.CreateCommand();
                cmd.CommandText = sql;
                cmd.Parameters.Add(new SqlParameter("@PurchaseId", purchaseId));

                using var reader = cmd.ExecuteReader();
                while (reader.Read())
                {
                    results.Add(new AllocationResultItem
                    {
                        ChargeType = reader.GetString(0),
                        RequestedMethod = reader.GetString(1),
                        UsedMethod = reader.GetString(2),
                        ItemCount = reader.GetInt32(3),
                        FallbackCount = reader.GetInt32(4)
                    });
                }
            }
            finally
            {
                if (wasClosed) conn.Close();
            }

            return results;
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
