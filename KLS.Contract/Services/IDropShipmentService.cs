using KLS.Contract.Dtos.DropShipment;

namespace KLS.Contract.Services
{
    public interface IDropShipmentService
    {
        DropShipmentInsertRes InsertSalesAndPO(DropShipmentInsertReq req);

        DropShipmentInsertRes GeneratePOFromSales(DropShipmentGeneratePoReq req);

        DropShipmentBackorderSeedRes CreateBackorderDropShip(int salesId);

        void UpdateShipQty(int purchaseId);

        void UpdateReceiptQty(int purchaseId, DropShipmentUpdateReceiptQtyReq req);

        void ConvertPOToBill(int purchaseId, DropShipmentConvertReq? req);

        void ReverseBill(int salesId);
    }
}
