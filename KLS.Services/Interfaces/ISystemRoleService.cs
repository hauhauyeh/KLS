using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services.Interfaces
{
    public interface ISystemRoleService
    {
        IEnumerable<SystemRole> GetAllRoles();

        SystemRole? GetById(int roleId);

        bool RoleNameExists(SystemRole role);

        SystemRole CreateRole(SystemRole role);

        SystemRole? UpdateRole(SystemRole role);

        void DeleteRole(int roleId);

        bool RoleUsed(int roleId);

        bool CheckPermission(int roleId, string endPoint);

        bool CheckMenuPermission(int roleId, string menuName);

        ICollection<ControllerGroup>? GetControllers(int roleId);

        void SavePermission(RolePermissionReq permissionReq);
    }
}
