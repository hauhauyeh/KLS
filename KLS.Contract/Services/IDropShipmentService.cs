using KLS.Contract.Dtos.DropShipment;

namespace KLS.Contract.Services
{
    public interface IDropShipmentService
    {
        DropShipmentInsertRes InsertSalesAndPO(DropShipmentInsertReq req);

        DropShipmentInsertRes GeneratePOFromSales(DropShipmentGeneratePoReq req);

        void UpdateShipQty(int purchaseId);

        void ConvertPOToBill(int purchaseId);

        void ReverseBill(int salesId);
    }
}
