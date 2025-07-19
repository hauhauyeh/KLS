using KLS.Contract.Interfaces;
using KLS.Models;
using KLS.Services.Interfaces;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services
{
    public class UserRoleService : BaseService, IUserRoleService
    {
        public UserRoleService(IUnitOfWork uow) : base(uow)
        {
        }

        public IEnumerable<UserRole> GetAllRoles()
        {
            return Uow.UserRoles
                      .GetAll()
                      .OrderBy(r => r.RoleName)
                      .ToList();
        }

        public UserRole? GetRoleById(int roleId)
        {
            return Uow.UserRoles.GetById(roleId);
        }

        public bool RoleNameExists(UserRole role)
        {
            return Uow.UserRoles.Exists(r =>
                r.RoleName!.ToLower() == role.RoleName!.ToLower() &&
                r.RoleId != role.RoleId);
        }

        public UserRole CreateRole(UserRole role)
        {
            Uow.UserRoles.Add(role);
            Uow.Commit();

            return role;
        }

        public UserRole? UpdateRole(UserRole role)
        {
            var existing = GetRoleById(role.RoleId);

            if (existing == null)
                return null;

            existing.RoleName = role.RoleName;
            existing.Inactive = role.Inactive;
            existing.IsAdmin = role.IsAdmin;
            existing.IsSalesRole = role.IsSalesRole;
            existing.Notes = role.Notes;
            existing.UpdatedAt = DateTime.UtcNow;

            Uow.UserRoles.Update(existing);
            Uow.Commit();

            return existing;
        }

        public void DeleteRole(int roleId)
        {
            Uow.UserRoles.RemoveById(roleId);
            Uow.Commit();
        }
    }
}
