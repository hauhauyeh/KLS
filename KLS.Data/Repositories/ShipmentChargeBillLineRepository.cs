using KLS.Contract.Interfaces;
using KLS.Data.DataContext;
using KLS.Models;

namespace KLS.Data.Repositories
{
    public class ShipmentChargeBillLineRepository : KLSRepository<ShipmentChargeBillLine>, IShipmentChargeBillLineRepository
    {
        public ShipmentChargeBillLineRepository(KLSDBContext dbContext) : base(dbContext)
        {
        }
    }
}
