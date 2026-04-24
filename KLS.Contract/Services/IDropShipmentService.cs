using KLS.Contract.Dtos.DropShipment;

namespace KLS.Contract.Services
{
    public interface IDropShipmentService
    {
        DropShipmentInsertRes InsertSalesAndPO(DropShipmentInsertReq req);
        void UpdateShipQty(DropShipmentUpdateShipQtyReq req);
        void ConvertPOToBill(DropShipmentConvertReq req);
    }
}
