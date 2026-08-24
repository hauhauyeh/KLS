using KLS.Models;

namespace KLS.Contract.Services
{
    public interface ISharedShipmentChargeBillService
    {
        IEnumerable<SharedShipmentChargeBillListDto> GetList();

        SharedShipmentChargeBillDto? GetById(int sharedShipmentChargeBillId);

        SharedShipmentChargeBillDto SaveDraft(SharedShipmentChargeBillSaveReq req);

        void DeleteDraft(int sharedShipmentChargeBillId);

        SharedShipmentChargeBillActionResult Apply(int sharedShipmentChargeBillId);

        SharedShipmentChargeBillActionResult Void(int sharedShipmentChargeBillId);
    }
}
