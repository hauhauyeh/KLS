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
            var factorPOParam = string.IsNullOrWhiteSpace(req.FactorPO)
                ? new SqlParameter("@FactorPO", DBNull.Value)
                : new SqlParameter("@FactorPO", req.FactorPO.Trim().ToUpper());
            var custPONumberParam = string.IsNullOrWhiteSpace(req.CustPONumber)
                ? new SqlParameter("@CustPONumber", DBNull.Value)
                : new SqlParameter("@CustPONumber", req.CustPONumber.Trim().ToUpper());
            var sourceSalesIdParam = req.SourceSalesId.HasValue
                ? new SqlParameter("@SourceSalesId", req.SourceSalesId.Value)
                : new SqlParameter("@SourceSalesId", DBNull.Value);

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
                "[DropShipment_InsertSalesAndPO] @SalesId,@PayeeId,@VendorPayeeId,@ShipDate,@ShipRoute,@Instruction,@EmpId,@PurchaseDate,@NewSalesId OUTPUT,@NewPurchaseId OUTPUT,@FactorPO,@CustPONumber,@SourceSalesId",
                salesIdParam, payeeIdParam, vendorPayeeIdParam, shipDateParam, shipRouteParam,
                instructionParam, empIdParam, purchaseDateParam, newSalesIdParam, newPurchaseIdParam, factorPOParam, custPONumberParam, sourceSalesIdParam);

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

        public DropShipmentBackorderCheckoutPrecheckRes PrecheckBackorderDropShipCheckout(DropShipmentInsertReq req)
        {
            var salesIdParam = new SqlParameter("@SalesId", req.SalesId);
            var sourceSalesIdParam = new SqlParameter("@SourceSalesId", req.SourceSalesId ?? 0);
            var payeeIdParam = new SqlParameter("@PayeeId", req.PayeeId);
            var vendorPayeeIdParam = new SqlParameter("@VendorPayeeId", req.VendorPayeeId);
            var empIdParam = new SqlParameter("@EmpId", UserContext.EmpId);

            var result = DbContext.DropShipmentBackorderCheckoutPrecheckRes
                .FromSqlRaw(
                    "[dbo].[DropShipment_PrecheckBackorderDropShipCheckout] @SalesId,@SourceSalesId,@PayeeId,@VendorPayeeId,@EmpId",
                    salesIdParam, sourceSalesIdParam, payeeIdParam, vendorPayeeIdParam, empIdParam)
                .AsNoTracking()
                .AsEnumerable()
                .SingleOrDefault();

            if (result == null)
                throw new InvalidOperationException("Backorder drop-ship checkout precheck did not return a result.");

            return result;
        }

        public DropShipmentInsertRes GeneratePOFromSales(DropShipmentGeneratePoReq req)
        {
            var salesIdParam = new SqlParameter("@SalesId", req.SalesId);
            var vendorPayeeIdParam = new SqlParameter("@VendorPayeeId", req.VendorPayeeId);
            var empIdParam = new SqlParameter("@EmpId", UserContext.EmpId);
            var arrivalDateParam = req.ArrivalDate.HasValue
                ? new SqlParameter("@ArrivalDate", req.ArrivalDate)
                : new SqlParameter("@ArrivalDate", DBNull.Value);
            var factorPOParam = string.IsNullOrWhiteSpace(req.FactorPO)
                ? new SqlParameter("@FactorPO", DBNull.Value)
                : new SqlParameter("@FactorPO", req.FactorPO.Trim().ToUpper());
            var custPONumberParam = string.IsNullOrWhiteSpace(req.CustPONumber)
                ? new SqlParameter("@CustPONumber", DBNull.Value)
                : new SqlParameter("@CustPONumber", req.CustPONumber.Trim().ToUpper());

            var newPurchaseIdParam = new SqlParameter
            {
                ParameterName = "@NewPurchaseId",
                Direction = System.Data.ParameterDirection.Output,
                SqlDbType = System.Data.SqlDbType.Int
            };

            DbContext.Database.ExecuteSqlRaw(
                "[DropShipment_GeneratePOFromSales] @SalesId,@VendorPayeeId,@EmpId,@ArrivalDate,@NewPurchaseId OUTPUT,@FactorPO,@CustPONumber",
                salesIdParam, vendorPayeeIdParam, empIdParam, arrivalDateParam, newPurchaseIdParam, factorPOParam, custPONumberParam);

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

        public DropShipmentBackorderSeedRes CreateBackorderDropShip(int salesId)
        {
            var salesIdParam = new SqlParameter("@SalesId", salesId);
            var empIdParam = new SqlParameter("@EmpId", UserContext.EmpId);

            var result = DbContext.DropShipmentBackorderSeedRes
                .FromSqlRaw(
                    "[dbo].[DropShipment_CreateBackorderDropShipToTemp] @SalesId,@EmpId",
                    salesIdParam, empIdParam)
                .AsNoTracking()
                .AsEnumerable()
                .SingleOrDefault();

            if (result == null)
                throw new InvalidOperationException("Backorder drop-ship seed did not return a result.");

            return result;
        }

        public void UpdateShipQty(int purchaseId)
        {
            var purchaseIdParam = new SqlParameter("@PurchaseId", purchaseId);
            var empIdParam = new SqlParameter("@EmpId", UserContext.EmpId);

            DbContext.Database.ExecuteSqlRaw(
                "[DropShipment_UpdateShipQty] @PurchaseId,@EmpId",
                purchaseIdParam, empIdParam);
        }

        public void UpdateReceiptQty(int purchaseId, DropShipmentUpdateReceiptQtyReq req)
        {
            var purchaseIdParam = new SqlParameter("@PurchaseId", purchaseId);
            var empIdParam = new SqlParameter("@EmpId", UserContext.EmpId);
            var itemsJsonParam = string.IsNullOrWhiteSpace(req.ItemsJson)
                ? new SqlParameter("@ItemsJson", DBNull.Value)
                : new SqlParameter("@ItemsJson", req.ItemsJson);

            DbContext.Database.ExecuteSqlRaw(
                "[DropShipment_UpdateReceiptQty] @PurchaseId,@EmpId,@ItemsJson",
                purchaseIdParam, empIdParam, itemsJsonParam);
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
