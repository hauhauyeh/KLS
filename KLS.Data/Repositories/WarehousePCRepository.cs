using KLS.Contract.Interfaces;
using KLS.Data.DataContext;
using KLS.Models;

namespace KLS.Data.Repositories
{
    public class WarehousePCRepository : KLSRepository<WarehousePC>, IWarehousePCRepository
    {
        public WarehousePCRepository(KLSDBContext dbContext) : base(dbContext)
        {
        }
    }
}
