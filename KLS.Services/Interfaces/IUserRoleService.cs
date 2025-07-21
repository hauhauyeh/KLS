using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services.Interfaces
{
    public interface IUserRoleService
    {
        IEnumerable<UserRole> GetAllRoles();

        UserRole? GetById(int roleId);

        bool RoleNameExists(UserRole role);

        UserRole CreateRole(UserRole role);

        UserRole? UpdateRole(UserRole role);

        void DeleteRole(int roleId);
    }
}
