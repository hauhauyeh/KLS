using KLS.Contract.Dtos.DropShipment;

namespace KLS.Contract.Interfaces
{
    public interface IDropShipmentRepository
    {
        DropShipmentInsertRes InsertSalesAndPO(DropShipmentInsertReq req);

        DropShipmentInsertRes GeneratePOFromSales(DropShipmentGeneratePoReq req);

        DropShipmentBackorderSeedRes CreateBackorderDropShip(int salesId);

        void UpdateShipQty(int purchaseId);

        void UpdateReceiptQty(int purchaseId, DropShipmentUpdateReceiptQtyReq req);

        void ConvertPOToBill(int purchaseId);

        void ReverseBill(int salesId);
    }
}
