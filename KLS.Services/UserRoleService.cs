using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Models;
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

        public IEnumerable<UserRole> GetAllUserRoles()
        {
            return Uow.UserRoles.GetAll().OrderBy(r => r.RoleName);
            //return Uow.UserRoles.Find(r => r.PayeeId == UserContext.EmpId).OrderBy(r => r.RoleName);
        }

        public UserRole GetById(int roleId)
        {
            return Uow.UserRoles.GetById(roleId);
        }

        public bool UserRoleNameExists(UserRole userRole)
        {
            return Uow.UserRoles.Exists(r =>
                r.RoleName!.ToLower() == userRole.RoleName!.ToLower() &&
                r.PayeeId == UserContext.EmpId &&
                r.RoleId != userRole.RoleId);
        }

        public UserRole CreateUserRole(UserRole userRole)
        {
            userRole.PayeeId = UserContext.EmpId;

            Uow.UserRoles.Add(userRole);
            Uow.Commit();

            return userRole;
        }

        public UserRole? UpdateUserRole(UserRole userRole)
        {
            var existing = GetById(userRole.RoleId);

            if (existing == null)
                return null;

            if (existing.PayeeId != UserContext.EmpId)
                return null;

            existing.RoleName = userRole.RoleName;
            existing.Inactive = userRole.Inactive;
            existing.IsAdmin = userRole.IsAdmin;
            existing.IsSalesRole = userRole.IsSalesRole;
            existing.Notes = userRole.Notes;
            existing.UpdatedAt = DateTime.UtcNow;

            Uow.UserRoles.Update(existing);
            Uow.Commit();

            return existing;
        }

        public void DeleteUserRole(int roleId)
        {
            var existing = GetById(roleId);

            if (existing != null && existing.PayeeId == UserContext.EmpId)
            {
                Uow.UserRoles.RemoveById(roleId);
                Uow.Commit();
            }
        }
    }
}
