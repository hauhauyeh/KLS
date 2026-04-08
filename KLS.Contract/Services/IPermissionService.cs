using KLS.Models;

namespace KLS.Contract.Services
{
    public interface IPermissionService
    {
        ICollection<Permission> GetAll();

        HashSet<string> GetPermissionKeys(int roleId);

        ICollection<PermissionGroup> GetGroupedByRole(int roleId);

        void SaveRolePermissions(int roleId, List<int> permissionIds);

        void InvalidateCache(int roleId);
    }
}
