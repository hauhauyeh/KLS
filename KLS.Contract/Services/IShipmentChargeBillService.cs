using KLS.Models;

namespace KLS.Contract.Services
{
    public interface IShipmentChargeBillService
    {
        IEnumerable<ShipmentChargeBillDto> GetByShipmentId(int shipmentId);

        ShipmentChargeBillDto? GetById(int shipmentChargeBillId);

        ShipmentChargeBillDto Save(ShipmentChargeBillSaveReq req);

        void Delete(int shipmentChargeBillId);
    }
}
