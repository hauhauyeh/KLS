using KLS.Contract.Interfaces;
using KLS.Data.DataContext;
using KLS.Models;

namespace KLS.Data.Repositories
{
    public class RolePermissionRepository : KLSRepository<RolePermission>, IRolePermissionRepository
    {
        public RolePermissionRepository(KLSDBContext dbContext) : base(dbContext)
        {
        }
    }
}
