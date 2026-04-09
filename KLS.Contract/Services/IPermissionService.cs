using KLS.Models;

namespace KLS.Contract.Services
{
    public interface IPermissionService
    {
        ICollection<Permission> GetAll();

        HashSet<string> GetPermissionKeys(int roleId);

        ICollection<PermissionModuleDTO> GetGroupedByRole(int roleId);

        void SaveRolePermissions(int roleId, List<string> permissionTokens);

        void InvalidateCache(int roleId);
    }
}
