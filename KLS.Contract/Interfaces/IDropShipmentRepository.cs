using KLS.Contract.Dtos.DropShipment;

namespace KLS.Contract.Interfaces
{
    public interface IDropShipmentRepository
    {
        DropShipmentInsertRes InsertSalesAndPO(DropShipmentInsertReq req);

        DropShipmentBackorderCheckoutPrecheckRes PrecheckBackorderDropShipCheckout(DropShipmentInsertReq req);

        DropShipmentInsertRes GeneratePOFromSales(DropShipmentGeneratePoReq req);

        DropShipmentBackorderSeedRes CreateBackorderDropShip(int salesId);

        void UpdateReceiptQty(int purchaseId, DropShipmentUpdateReceiptQtyReq req);

        void ConvertPOToBill(int purchaseId, DropShipmentConvertReq req);

        void ReverseBill(int salesId);
    }
}
