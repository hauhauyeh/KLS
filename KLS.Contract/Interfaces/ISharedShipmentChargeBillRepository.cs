using KLS.Models;

namespace KLS.Contract.Interfaces
{
    public interface ISharedShipmentChargeBillRepository : IRepository<SharedShipmentChargeBill>
    {
        SharedShipmentChargeBillActionResult Apply(int sharedShipmentChargeBillId);

        SharedShipmentChargeBillActionResult Void(int sharedShipmentChargeBillId);
    }
}
