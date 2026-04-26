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

        public void UpdateShipQty(DropShipmentUpdateShipQtyReq req)
        {
            Uow.DropShipments.UpdateShipQty(req.PurchaseId);
        }

        public void ConvertPOToBill(DropShipmentConvertReq req)
        {
            Uow.DropShipments.ConvertPOToBill(req);
        }
    }
}
