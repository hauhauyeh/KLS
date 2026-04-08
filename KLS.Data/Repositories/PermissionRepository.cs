using KLS.Contract.Interfaces;
using KLS.Data.DataContext;
using KLS.Models;

namespace KLS.Data.Repositories
{
    public class PermissionRepository : KLSRepository<Permission>, IPermissionRepository
    {
        public PermissionRepository(KLSDBContext dbContext) : base(dbContext)
        {
        }
    }
}
