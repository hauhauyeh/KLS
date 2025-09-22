using KLS.Contract.Interfaces;
using KLS.Models;
using KLS.Services.Interfaces;
using Microsoft.AspNetCore.Mvc;
using Newtonsoft.Json;
using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel;
using System.Linq;
using System.Reflection;
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
            var cloneRole = GetById(role.CloneId);

            if (cloneRole != null)
                role.RoleAccess = cloneRole.RoleAccess;

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

        public bool RoleUsed(int roleId)
        {
            return Uow.SystemUsers.Exists(c => c.SystemRoleId == roleId);
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

        public ICollection<ControllerGroup>? GetControllers(int roleId)
        {
            var role = GetById(roleId);

            var groups = GetAdminControllerActions();

            if (role != null && !string.IsNullOrEmpty(role.RoleAccess))
            {
                var permission = JsonConvert.DeserializeObject<List<ControllerGroup>>(role.RoleAccess);

                foreach (var group in groups)
                {
                    var pgroup = permission?.Where(g => g.GroupName == group.GroupName).FirstOrDefault();

                    if (pgroup != null)
                        group.IsAllow = pgroup.IsAllow;

                    foreach (var controller in group.Controllers)
                    {
                        var pcontroller = permission?.SelectMany(g => g.Controllers.Where(c => c.Id == controller.Id)).FirstOrDefault();

                        if (pcontroller != null)
                            controller.IsAllow = pcontroller.IsAllow;

                        foreach (var action in controller.Actions)
                        {
                            var paction = permission?.SelectMany(g => g.Controllers.SelectMany(c => c.Actions.Where(a => a.Id == action.Id))).FirstOrDefault();

                            if (paction != null)
                                action.IsAllow = paction.IsAllow;
                        }
                    }
                }
            }

            return groups;
        }

        public void SavePermission(RolePermissionReq permissionReq)
        {
            var role = GetById(permissionReq.RoleId);

            if (role != null)
            {
                string accessJson = JsonConvert.SerializeObject(permissionReq.Permission);

                role.RoleAccess = accessJson;
                role.UpdatedAt = DateTime.UtcNow;

                Uow.SystemRoles.Update(role);
                Uow.Commit();
            }
        }

        private static ICollection<ControllerGroup> GetAdminControllerActions()
        {
            Assembly asm = Assembly.GetExecutingAssembly();

            var controllers = new List<ControllerInfo>();

            var controllerList = asm.GetTypes()
                .Where(type => typeof(ControllerBase).IsAssignableFrom(type)
                               && type.Namespace != null
                               && type.Namespace.Contains(".Admin")) // only Admin folder
                .ToList();

            foreach (var con in controllerList)
            {
                string conName = con.Name.Replace("Controller", "");

                var controller = new ControllerInfo
                {
                    Name = conName,
                    DisplayName = con.GetCustomAttribute<DisplayAttribute>()?.Name,
                    GroupName = con.GetCustomAttribute<DisplayAttribute>()?.GroupName
                };

                var actions = con.GetMethods(BindingFlags.Instance | BindingFlags.DeclaredOnly | BindingFlags.Public);

                var actionList = new List<ActionInfo>();

                foreach (var itemaction in actions)
                {
                    var action = new ActionInfo
                    {
                        ControllerName = conName,
                        Name = itemaction.Name,
                        DisplayName = itemaction.GetCustomAttribute<DisplayNameAttribute>()?.DisplayName,
                        Attributes = string.Join(",", itemaction.GetCustomAttributes()
                                                               .Select(a => a.GetType().Name.Replace("Attribute", "")))
                    };

                    if (action.Attributes.Contains("DisplayName"))
                        actionList.Add(action);
                }

                controller.Actions = actionList.OrderBy(c => c.DisplayName).ToList();

                if (actionList.Count > 0)
                    controllers.Add(controller);
            }

            var contGroups = controllers
                .Where(c => c.GroupName != null)
                .GroupBy(c => c.GroupName)
                .ToList();

            var groups = new List<ControllerGroup>();

            foreach (var group in contGroups)
            {
                groups.Add(new ControllerGroup
                {
                    GroupName = group.Key,
                    Controllers = group.OrderBy(c => c.DisplayName).ToList()
                });
            }

            return groups;
        }
    }
}
