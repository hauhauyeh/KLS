using KLS.Contract.Dtos.DropShipment;

namespace KLS.Contract.Interfaces
{
    public interface IDropShipmentRepository
    {
        DropShipmentInsertRes InsertSalesAndPO(DropShipmentInsertReq req);

        void UpdateShipQty(int purchaseId);

        void ConvertPOToBill(int purchaseId);

        void ReverseBill(int salesId);
    }
}
