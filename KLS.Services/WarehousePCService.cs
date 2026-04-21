using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Models;

namespace KLS.Services
{
    public class WarehousePCService : BaseService, IWarehousePCService
    {
        public WarehousePCService(IUnitOfWork uow) : base(uow)
        {
        }

        public IEnumerable<WarehousePC> GetList()
        {
            return Uow.WarehousePCs.GetAll();
        }

        public WarehousePC GetById(int warehousePCId)
        {
            return Uow.WarehousePCs.GetById(warehousePCId);
        }

        public WarehousePC Create(WarehousePC warehousePC)
        {
            Uow.WarehousePCs.Add(warehousePC);
            Uow.Commit();
            return warehousePC;
        }

        public WarehousePC? Update(WarehousePC warehousePC)
        {
            var existing = GetById(warehousePC.WarehousePCId);
            if (existing != null)
            {
                existing.IPAddress = warehousePC.IPAddress;
                existing.PrinterName = warehousePC.PrinterName;
                Uow.WarehousePCs.Update(existing);
                Uow.Commit();
            }
            return existing;
        }

        public void Delete(int warehousePCId)
        {
            Uow.WarehousePCs.RemoveById(warehousePCId);
            Uow.Commit();
        }
    }
}
