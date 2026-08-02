using KLS.Common;
using KLS.Contract.Dtos.DropShipment;
using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using Microsoft.AspNetCore.Http;

namespace KLS.Services
{
    public class DropShipmentService : BaseService, IDropShipmentService
    {
        private readonly IHttpContextAccessor _httpContextAccessor;

        public DropShipmentService(IUnitOfWork uow, IHttpContextAccessor httpContextAccessor) : base(uow)
        {
            _httpContextAccessor = httpContextAccessor;
        }

        public DropShipmentInsertRes InsertSalesAndPO(DropShipmentInsertReq req)
        {
            if (req.IsBackorderDropShip)
                PrecheckBackorderDropShipCheckout(req);

            return Uow.DropShipments.InsertSalesAndPO(req);
        }

        public DropShipmentInsertRes GeneratePOFromSales(DropShipmentGeneratePoReq req)
        {
            return Uow.DropShipments.GeneratePOFromSales(req);
        }

        public DropShipmentBackorderSeedRes CreateBackorderDropShip(int salesId)
        {
            RequireCustomerSaleCreatePermission();

            return Uow.DropShipments.CreateBackorderDropShip(salesId);
        }

        public void UpdateShipQty(int purchaseId)
        {
            Uow.DropShipments.UpdateShipQty(purchaseId);
        }

        public void UpdateReceiptQty(int purchaseId, DropShipmentUpdateReceiptQtyReq req)
        {
            if (req == null || string.IsNullOrWhiteSpace(req.ItemsJson))
                throw new ArgumentException("Receipt items are required.");

            if (!req.ReceiptDate.HasValue)
                throw new ArgumentException("Receipt date is required.");

            Uow.DropShipments.UpdateReceiptQty(purchaseId, req);
        }

        public void ConvertPOToBill(int purchaseId)
        {
            Uow.DropShipments.ConvertPOToBill(purchaseId);
        }

        public void ReverseBill(int salesId)
        {
            Uow.DropShipments.ReverseBill(salesId);
        }

        private void RequireCustomerSaleCreatePermission()
        {
            var httpContext = _httpContextAccessor.HttpContext;

            if (httpContext?.Items["IsAdmin"] is bool isAdmin && isAdmin)
                return;

            if (httpContext?.Items["PermissionKeys"] is HashSet<string> permissionKeys &&
                permissionKeys.Contains("Customer.Sale.Create"))
                return;

            throw new UnauthorizedAccessException("Customer sale create permission is required.");
        }

        private void PrecheckBackorderDropShipCheckout(DropShipmentInsertReq req)
        {
            if (!req.SourceSalesId.HasValue || req.SourceSalesId.Value <= 0)
                throw new InvalidOperationException("Source sales order is required.");

            var result = Uow.DropShipments.PrecheckBackorderDropShipCheckout(req);

            if (!result.CanPost)
                throw new InvalidOperationException(result.Message ?? "Backorder drop-ship checkout cannot be posted.");
        }
    }
}
