using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Services
{
    public interface IUserRoleService
    {
        IEnumerable<UserRole> GetAllUserRoles();

        UserRole GetById(int roleId);

        bool UserRoleNameExists(UserRole userRole);

        UserRole CreateUserRole(UserRole userRole);

        UserRole? UpdateUserRole(UserRole userRole);

        void DeleteUserRole(int roleId);
    }
}
