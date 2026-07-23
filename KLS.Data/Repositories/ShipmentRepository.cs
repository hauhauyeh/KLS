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

        public void GenerateChargeBills(int shipmentId)
        {
            var ShipmentIdParam = new SqlParameter("@ShipmentId", shipmentId);

            DbContext.Database.ExecuteSqlRaw("[Shipment_GenerateChargeBills] @ShipmentId", ShipmentIdParam);
        }

        public bool HasChargeBills(int shipmentId)
        {
            var conn = DbContext.Database.GetDbConnection();
            var wasClosed = conn.State != System.Data.ConnectionState.Open;

            if (wasClosed) conn.Open();
            try
            {
                using var cmd = conn.CreateCommand();
                cmd.CommandText = "SELECT CASE WHEN EXISTS (SELECT 1 FROM dbo.ShipmentChargeBill WHERE ShipmentId = @ShipmentId) THEN 1 ELSE 0 END";
                cmd.Parameters.Add(new SqlParameter("@ShipmentId", shipmentId));

                return Convert.ToInt32(cmd.ExecuteScalar()) == 1;
            }
            finally
            {
                if (wasClosed) conn.Close();
            }
        }

        public void RebuildChargesFromChargeBills(int shipmentId)
        {
            var ShipmentIdParam = new SqlParameter("@ShipmentId", shipmentId);

            DbContext.Database.ExecuteSqlRaw("[ShipmentCharge_RebuildFromChargeBills] @ShipmentId", ShipmentIdParam);
        }

        public void RefreshSingleBillAllocation(int shipmentId)
        {
            var ShipmentIdParam = new SqlParameter("@ShipmentId", shipmentId);

            DbContext.Database.ExecuteSqlRaw("[ShipmentCharge_RefreshSingleBillAllocation] @ShipmentId", ShipmentIdParam);
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

        public IEnumerable<EligibleBill>? EligibleBills(int shipmentId, string? search)
        {
            var ShipmentIdParam = new SqlParameter("@ShipmentId", shipmentId);
            var SearchParam = string.IsNullOrWhiteSpace(search)
                ? new SqlParameter("@Search", DBNull.Value)
                : new SqlParameter("@Search", search);

            return DbContext.EligibleBill
                .FromSqlRaw("[Shipment_EligibleBills] @ShipmentId,@Search", ShipmentIdParam, SearchParam)
                .AsNoTracking()
                .ToList();
        }

        public void AssignBills(int shipmentId, string purchaseIds)
        {
            var ShipmentIdParam = new SqlParameter("@ShipmentId", shipmentId);
            var PurchaseIdsParam = new SqlParameter("@PurchaseIds", purchaseIds);

            DbContext.Database.ExecuteSqlRaw("[Shipment_AssignBills] @ShipmentId,@PurchaseIds", ShipmentIdParam, PurchaseIdsParam);
        }

        public IEnumerable<BillBasisUsability> BillBasisUsability(int shipmentId)
        {
            var ShipmentIdParam = new SqlParameter("@ShipmentId", shipmentId);

            return DbContext.BillBasisUsability
                .FromSqlRaw("[Shipment_BillBasisUsability] @ShipmentId", ShipmentIdParam)
                .AsNoTracking()
                .ToList();
        }

        public IEnumerable<ShipmentReallocationCandidate> ReallocationCandidates(int shipmentId)
        {
            var ShipmentIdParam = new SqlParameter("@ShipmentId", shipmentId);

            var sql = """
                WITH Linked AS
                (
                    SELECT
                        sp.ShipmentId,
                        sp.ShipmentPurchaseId,
                        p.PurchaseId,
                        p.PurchaseNumber,
                        p.StageId,
                        p.IsDropShip,
                        p.IsLocked,
                        PaymentApplied = ISNULL(p.PaymentApplied, 0),
                        DiscountApplied = ISNULL(p.DiscountApplied, 0)
                    FROM dbo.ShipmentPurchase sp
                    INNER JOIN dbo.Purchase p ON p.PurchaseId = sp.PurchaseId
                    WHERE sp.ShipmentId = @ShipmentId
                ),
                Alloc AS
                (
                    SELECT
                        l.PurchaseId,
                        LastAllocAt = MAX(sa.CreatedAt)
                    FROM Linked l
                    INNER JOIN dbo.PurchaseDetail pd ON pd.PurchaseId = l.PurchaseId
                    INNER JOIN dbo.ShipmentAllocation sa ON sa.PurchaseDetailId = pd.PurchaseDetailId
                    INNER JOIN dbo.ShipmentCharge sc ON sc.ChargeId = sa.ChargeId
                    INNER JOIN dbo.ShipmentPurchase sp
                        ON sp.ShipmentId = sc.ShipmentId
                       AND sp.PurchaseId = l.PurchaseId
                    GROUP BY l.PurchaseId
                ),
                Flags AS
                (
                    SELECT
                        l.PurchaseId,
                        a.LastAllocAt,
                        IsStale = CAST(CASE
                            WHEN a.LastAllocAt IS NOT NULL
                             AND (
                                EXISTS
                                (
                                    SELECT 1
                                    FROM dbo.PurchaseDetail pd
                                    INNER JOIN dbo.Item i ON i.ItemId = pd.ItemId
                                    WHERE pd.PurchaseId = l.PurchaseId
                                      AND pd.ItemId IS NOT NULL
                                      AND i.UpdatedAt > a.LastAllocAt
                                )
                                OR EXISTS
                                (
                                    SELECT 1
                                    FROM dbo.ShipmentCharge sc
                                    WHERE sc.ShipmentId = l.ShipmentId
                                      AND sc.UpdatedAt IS NOT NULL
                                      AND sc.UpdatedAt > a.LastAllocAt
                                )
                             )
                            THEN 1 ELSE 0
                        END AS bit),
                        IsMissingAllocation = CAST(CASE
                            WHEN a.LastAllocAt IS NULL
                             AND EXISTS
                             (
                                SELECT 1
                                FROM dbo.ShipmentCharge sc
                                WHERE sc.ShipmentId = l.ShipmentId
                                  AND ISNULL(sc.ChargeAmount, 0) <> 0
                             )
                            THEN 1 ELSE 0
                        END AS bit)
                    FROM Linked l
                    LEFT JOIN Alloc a ON a.PurchaseId = l.PurchaseId
                )
                SELECT
                    l.ShipmentId,
                    l.ShipmentPurchaseId,
                    l.PurchaseId,
                    l.PurchaseNumber,
                    l.StageId,
                    l.IsDropShip,
                    l.IsLocked,
                    l.PaymentApplied,
                    l.DiscountApplied,
                    f.LastAllocAt,
                    f.IsStale,
                    f.IsMissingAllocation,
                    Action = CASE
                        WHEN l.IsDropShip = 1 THEN 'SKIP_DROP_SHIP'
                        WHEN ISNULL(l.StageId, 0) <> 6
                          OR l.IsLocked = 1
                          OR l.PaymentApplied <> 0
                          OR l.DiscountApplied <> 0 THEN 'SKIP_BLOCKED'
                        WHEN f.IsStale = 1 OR f.IsMissingAllocation = 1 THEN 'GO'
                        ELSE 'NO_ACTION'
                    END,
                    Reason = CASE
                        WHEN l.IsDropShip = 1 THEN 'Drop-ship bill is excluded from landed-cost allocation.'
                        WHEN ISNULL(l.StageId, 0) <> 6 THEN 'Goods bill is not in Bill stage.'
                        WHEN l.IsLocked = 1 THEN 'Goods bill is locked.'
                        WHEN l.PaymentApplied <> 0 THEN 'Goods bill has payment applied.'
                        WHEN l.DiscountApplied <> 0 THEN 'Goods bill has discount applied.'
                        WHEN f.IsStale = 1 THEN 'Needs reallocation.'
                        WHEN f.IsMissingAllocation = 1 THEN 'Missing allocation.'
                        ELSE 'No reallocation needed.'
                    END
                FROM Linked l
                INNER JOIN Flags f ON f.PurchaseId = l.PurchaseId
                ORDER BY l.PurchaseNumber
                """;

            return DbContext.ShipmentReallocationCandidate
                .FromSqlRaw(sql, ShipmentIdParam)
                .AsNoTracking()
                .ToList();
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
