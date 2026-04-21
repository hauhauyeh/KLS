using KLS.Models;

namespace KLS.Contract.Services
{
    public interface IWarehousePCService
    {
        IEnumerable<WarehousePC> GetList();
        WarehousePC GetById(int warehousePCId);
        WarehousePC Create(WarehousePC warehousePC);
        WarehousePC? Update(WarehousePC warehousePC);
        void Delete(int warehousePCId);
    }
}
