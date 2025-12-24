using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Services
{
    public interface ISystemRoleService
    {
        IEnumerable<SystemRole> GetList();

        SystemRole? GetById(int roleId);

        bool NameExists(SystemRole role);

        SystemRole Create(SystemRole role);

        SystemRole? Update(SystemRole role);

        void Delete(int roleId);

        bool RoleUsed(int roleId);

        bool CheckPermission(int roleId, string endPoint);

        bool CheckMenuPermission(int roleId, string menuName);

        ICollection<ControllerGroup>? GetControllers(int roleId);

        void SavePermission(RolePermissionReq permissionReq);
    }
}
