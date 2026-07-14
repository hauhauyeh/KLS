using KLS.Common;
using KLS.Contract.Dtos.DropShipment;
using KLS.Contract.Interfaces;
using KLS.Contract.Services;

namespace KLS.Services
{
    public class DropShipmentService : BaseService, IDropShipmentService
    {
        public DropShipmentService(IUnitOfWork uow) : base(uow)
        {
        }

        public DropShipmentInsertRes InsertSalesAndPO(DropShipmentInsertReq req)
        {
            return Uow.DropShipments.InsertSalesAndPO(req);
        }

        public DropShipmentInsertRes GeneratePOFromSales(DropShipmentGeneratePoReq req)
        {
            return Uow.DropShipments.GeneratePOFromSales(req);
        }

        public void UpdateShipQty(int purchaseId)
        {
            Uow.DropShipments.UpdateShipQty(purchaseId);
        }

        public void ConvertPOToBill(int purchaseId)
        {
            Uow.DropShipments.ConvertPOToBill(purchaseId);
        }

        public void ReverseBill(int salesId)
        {
            Uow.DropShipments.ReverseBill(salesId);
        }
    }
}
