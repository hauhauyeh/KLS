using KLS.Contract.Dtos.DropShipment;

namespace KLS.Contract.Interfaces
{
    public interface IDropShipmentRepository
    {
        DropShipmentInsertRes InsertSalesAndPO(DropShipmentInsertReq req, int empId);
        void UpdateShipQty(int purchaseId, int empId);
        void ConvertPOToBill(DropShipmentConvertReq req, int empId);
    }
}
