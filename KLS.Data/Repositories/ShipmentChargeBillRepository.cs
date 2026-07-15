using KLS.Contract.Interfaces;
using KLS.Data.DataContext;
using KLS.Models;

namespace KLS.Data.Repositories
{
    public class ShipmentChargeBillRepository : KLSRepository<ShipmentChargeBill>, IShipmentChargeBillRepository
    {
        public ShipmentChargeBillRepository(KLSDBContext dbContext) : base(dbContext)
        {
        }
    }
}
