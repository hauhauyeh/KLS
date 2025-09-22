using KLS.Contract.Interfaces;
using KLS.Models;
using KLS.Services.Interfaces;
using Newtonsoft.Json;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services
{
    public class SystemRoleService : BaseService, ISystemRoleService
    {
        public SystemRoleService(IUnitOfWork uow) : base(uow)
        {
        }

        public IEnumerable<SystemRole> GetAllRoles()
        {
            return Uow.SystemRoles
                      .GetAll()
                      .OrderBy(r => r.RoleName)
                      .ToList();
        }

        public SystemRole? GetById(int roleId)
        {
            return Uow.SystemRoles.GetById(roleId);
        }

        public bool RoleNameExists(SystemRole role)
        {
            return Uow.SystemRoles.Exists(r =>
                r.RoleName!.ToLower() == role.RoleName!.ToLower() &&
                r.SystemRoleId != role.SystemRoleId);
        }

        public SystemRole CreateRole(SystemRole role)
        {
            Uow.SystemRoles.Add(role);
            Uow.Commit();

            return role;
        }

        public SystemRole? UpdateRole(SystemRole role)
        {
            var existing = GetById(role.SystemRoleId);

            if (existing == null)
                return null;

            existing.RoleName = role.RoleName;
            existing.Inactive = role.Inactive;
            existing.IsAdmin = role.IsAdmin;
            existing.IsSalesRole = role.IsSalesRole;
            existing.Notes = role.Notes;
            existing.UpdatedAt = DateTime.UtcNow;

            Uow.SystemRoles.Update(existing);
            Uow.Commit();

            return existing;
        }

        public void DeleteRole(int roleId)
        {
            Uow.SystemRoles.RemoveById(roleId);
            Uow.Commit();
        }

        public bool CheckPermission(int roleId, string endPoint)
        {
            var role = GetById(roleId);

            if (!string.IsNullOrEmpty(role.RoleAccess))
            {
                var permissions = JsonConvert.DeserializeObject<List<ControllerGroup>>(role.RoleAccess);

                return permissions.SelectMany(g => g.Controllers.SelectMany(c => c.Actions.Where(a => a.Id.ToLower() == endPoint.ToLower()))).Any();
            }
            else
                return false;
        }

        public bool CheckMenuPermission(int roleId, string menuName)
        {
            var role = GetById(roleId);

            if (!string.IsNullOrEmpty(role.RoleAccess))
            {
                var permissions = JsonConvert.DeserializeObject<List<ControllerGroup>>(role.RoleAccess);

                return permissions.Where(g => g.GroupName.ToLower().Contains(menuName.ToLower())).Any();
            }
            else
                return false;
        }
    }
}
