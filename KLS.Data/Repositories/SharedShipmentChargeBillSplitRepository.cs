using KLS.Contract.Interfaces;
using KLS.Data.DataContext;
using KLS.Models;

namespace KLS.Data.Repositories
{
    public class SharedShipmentChargeBillSplitRepository : KLSRepository<SharedShipmentChargeBillSplit>, ISharedShipmentChargeBillSplitRepository
    {
        public SharedShipmentChargeBillSplitRepository(KLSDBContext dbContext) : base(dbContext)
        {
        }
    }
}
