using KLS.Common;
using KLS.Contract.Dtos.DropShipment;
using KLS.Contract.Interfaces;
using KLS.Data.DataContext;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;

namespace KLS.Data.Repositories
{
    public class DropShipmentRepository : IDropShipmentRepository
    {
        private readonly KLSDBContext DbContext;

        public DropShipmentRepository(KLSDBContext dbContext)
        {
            DbContext = dbContext;
        }

        public DropShipmentInsertRes InsertSalesAndPO(DropShipmentInsertReq req)
        {
            var salesIdParam = new SqlParameter("@SalesId", req.SalesId);
            var payeeIdParam = new SqlParameter("@PayeeId", req.PayeeId);
            var vendorPayeeIdParam = new SqlParameter("@VendorPayeeId", req.VendorPayeeId);
            var shipDateParam = req.ShipDate.HasValue
                ? new SqlParameter("@ShipDate", req.ShipDate)
                : new SqlParameter("@ShipDate", DBNull.Value);
            var shipRouteParam = !string.IsNullOrEmpty(req.ShipRoute)
                ? new SqlParameter("@ShipRoute", req.ShipRoute)
                : new SqlParameter("@ShipRoute", DBNull.Value);
            var instructionParam = !string.IsNullOrEmpty(req.Instruction)
                ? new SqlParameter("@Instruction", req.Instruction)
                : new SqlParameter("@Instruction", DBNull.Value);
            var empIdParam = new SqlParameter("@EmpId", UserContext.EmpId);
            var purchaseDateParam = req.PurchaseDate.HasValue
                ? new SqlParameter("@PurchaseDate", req.PurchaseDate)
                : new SqlParameter("@PurchaseDate", DBNull.Value);

            var newSalesIdParam = new SqlParameter
            {
                ParameterName = "@NewSalesId",
                Direction = System.Data.ParameterDirection.Output,
                SqlDbType = System.Data.SqlDbType.Int
            };
            var newPurchaseIdParam = new SqlParameter
            {
                ParameterName = "@NewPurchaseId",
                Direction = System.Data.ParameterDirection.Output,
                SqlDbType = System.Data.SqlDbType.Int
            };

            DbContext.Database.ExecuteSqlRaw(
                "[DropShipment_InsertSalesAndPO] @SalesId,@PayeeId,@VendorPayeeId,@ShipDate,@ShipRoute,@Instruction,@EmpId,@PurchaseDate,@NewSalesId OUTPUT,@NewPurchaseId OUTPUT",
                salesIdParam, payeeIdParam, vendorPayeeIdParam, shipDateParam, shipRouteParam,
                instructionParam, empIdParam, purchaseDateParam, newSalesIdParam, newPurchaseIdParam);

            var newSalesId = Convert.ToInt32(newSalesIdParam.Value);
            var newPurchaseId = Convert.ToInt32(newPurchaseIdParam.Value);

            var sales = DbContext.Sales.AsNoTracking().FirstOrDefault(s => s.SalesId == newSalesId);
            var purchase = DbContext.Purchases.AsNoTracking().FirstOrDefault(p => p.PurchaseId == newPurchaseId);

            return new DropShipmentInsertRes
            {
                SalesId = newSalesId,
                SalesNumber = sales?.SalesNumber ?? 0,
                PurchaseId = newPurchaseId,
                PurchaseNumber = purchase?.PurchaseNumber ?? 0
            };
        }

        public DropShipmentInsertRes GeneratePOFromSales(DropShipmentGeneratePoReq req)
        {
            var salesIdParam = new SqlParameter("@SalesId", req.SalesId);
            var vendorPayeeIdParam = new SqlParameter("@VendorPayeeId", req.VendorPayeeId);
            var empIdParam = new SqlParameter("@EmpId", UserContext.EmpId);
            var arrivalDateParam = req.ArrivalDate.HasValue
                ? new SqlParameter("@ArrivalDate", req.ArrivalDate)
                : new SqlParameter("@ArrivalDate", DBNull.Value);

            var newPurchaseIdParam = new SqlParameter
            {
                ParameterName = "@NewPurchaseId",
                Direction = System.Data.ParameterDirection.Output,
                SqlDbType = System.Data.SqlDbType.Int
            };

            DbContext.Database.ExecuteSqlRaw(
                "[DropShipment_GeneratePOFromSales] @SalesId,@VendorPayeeId,@EmpId,@ArrivalDate,@NewPurchaseId OUTPUT",
                salesIdParam, vendorPayeeIdParam, empIdParam, arrivalDateParam, newPurchaseIdParam);

            var newPurchaseId = Convert.ToInt32(newPurchaseIdParam.Value);

            var sales = DbContext.Sales.AsNoTracking().FirstOrDefault(s => s.SalesId == req.SalesId);
            var purchase = DbContext.Purchases.AsNoTracking().FirstOrDefault(p => p.PurchaseId == newPurchaseId);

            return new DropShipmentInsertRes
            {
                SalesId = req.SalesId,
                SalesNumber = sales?.SalesNumber ?? 0,
                PurchaseId = newPurchaseId,
                PurchaseNumber = purchase?.PurchaseNumber ?? 0
            };
        }

        public void UpdateShipQty(int purchaseId)
        {
            var purchaseIdParam = new SqlParameter("@PurchaseId", purchaseId);
            var empIdParam = new SqlParameter("@EmpId", UserContext.EmpId);

            DbContext.Database.ExecuteSqlRaw(
                "[DropShipment_UpdateShipQty] @PurchaseId,@EmpId",
                purchaseIdParam, empIdParam);
        }

        public void ConvertPOToBill(int purchaseId)
        {
            var purchaseIdParam = new SqlParameter("@PurchaseId", purchaseId);
            var empIdParam = new SqlParameter("@EmpId", UserContext.EmpId);

            DbContext.Database.ExecuteSqlRaw(
                "[DropShipment_ConvertPOToBill] @PurchaseId,@EmpId",
                purchaseIdParam, empIdParam);
        }

        public void ReverseBill(int salesId)
        {
            var salesIdParam = new SqlParameter("@SalesId", salesId);

            DbContext.Database.ExecuteSqlRaw(
                "[DropShipment_ReverseBill] @SalesId", salesIdParam);
        }
    }
}
