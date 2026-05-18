using KLS.Contract.Dtos.DropShipment;

namespace KLS.Contract.Services
{
    public interface IDropShipmentService
    {
        DropShipmentInsertRes InsertSalesAndPO(DropShipmentInsertReq req);

        void UpdateShipQty(int purchaseId);

        void ConvertPOToBill(int purchaseId);

        void ReverseBill(int salesId);
    }
}
