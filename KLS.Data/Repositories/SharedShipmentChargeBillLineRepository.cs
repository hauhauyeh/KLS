using KLS.Contract.Interfaces;
using KLS.Data.DataContext;
using KLS.Models;

namespace KLS.Data.Repositories
{
    public class SharedShipmentChargeBillLineRepository : KLSRepository<SharedShipmentChargeBillLine>, ISharedShipmentChargeBillLineRepository
    {
        public SharedShipmentChargeBillLineRepository(KLSDBContext dbContext) : base(dbContext)
        {
        }
    }
}
