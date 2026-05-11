using KLS.API.Helpers;
using KLS.Contract.Services;
using KLS.Models;
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel;
using System.ComponentModel.DataAnnotations;

namespace KLS.API.Controllers.Admin
{
    [AuthorizeAdmin]
    [SuperAdminOnly]
    [Route("api/admin/[controller]")]
    [Display(Name = "Role Management", GroupName = "Admin")]
    public class RolesController : BaseController
    {
        #region --- Member(s) ---

        private readonly ISystemRoleService _roleService;
        private readonly IPermissionService _permissionService;

        #endregion

        #region --- Constructor(s) ---

        public RolesController(ISystemRoleService roleService, IPermissionService permissionService)
        {
            _roleService = roleService;
            _permissionService = permissionService;
        }

        #endregion

        #region --- Method(s) ---

        [HttpGet]
        [DisplayName("List Roles")]
        [PermissionKey("Admin.Role.List")]
        public IActionResult List()
        {
            return Ok(_roleService.GetList());
        }


        [HttpGet("{id}")]
        public IActionResult GetById(int id)
        {
            var role = _roleService.GetById(id);

            if (role == null)
                return NotFound($"User role with ID {id} not found.");

            return Ok(role);
        }


        [HttpPost]
        [DisplayName("Create Role")]
        [PermissionKey("Admin.Role.Create")]
        public IActionResult Create([FromBody] SystemRole role)
        {
            if (_roleService.NameExists(role))
                return Conflict("Rolename already exists.");

            var created = _roleService.Create(role);

            return Ok(created);
        }


        [HttpPut]
        [DisplayName("Update Role")]
        [PermissionKey("Admin.Role.Update")]
        public IActionResult Update([FromBody] SystemRole role)
        {
            if (_roleService.NameExists(role))
                return Conflict("Rolename already exists.");

            var updated = _roleService.Update(role);

            return Ok(updated);
        }


        [HttpDelete("{roleId}")]
        [DisplayName("Delete Role")]
        [PermissionKey("Admin.Role.Delete")]
        public IActionResult Delete(int roleId)
        {
            var existing = _roleService.GetById(roleId);

            if (existing == null)
                return NotFound($"User role with ID {roleId} not found.");

            if (_roleService.RoleUsed(roleId))
                return Conflict("This Role can't be deleted as it is linked to an employee.");

            _roleService.Delete(roleId);

            return Ok();
        }


        [HttpGet("GetPermissions/{roleId}")]
        [DisplayName("View Permission")]
        [PermissionKey("Admin.Role.ViewPermission")]
        public IActionResult GetPermissions(int roleId)
        {
            return Ok(_permissionService.GetGroupedByRole(roleId));
        }


        [HttpPost("SavePermissions/{roleId}")]
        [DisplayName("Save Permission")]
        [PermissionKey("Admin.Role.SavePermission")]
        public IActionResult SavePermissions(int roleId, [FromBody] List<string> permissionTokens)
        {
            _permissionService.SaveRolePermissions(roleId, permissionTokens);

            return Ok();
        }

        #endregion

        #region --- Deprecated ---

        /* [DEPRECATED-PERMISSION] Old HTTP-based permission check endpoints.
           Frontend now checks permissions locally from login response.
           Uncomment to rollback.

        [HttpGet("CheckPermission/{endPoint}")]
        public IActionResult CheckPermission(string endPoint)
        {
            var isAdmin = Convert.ToBoolean(HttpContext.Items["IsAdmin"]);

            if (isAdmin)
                return Ok(true);

            var roleId = Convert.ToInt32(HttpContext.Items["RoleId"]);

            return Ok(_roleService.CheckPermission(roleId, endPoint));
        }


        [HttpGet("MenuPermission/{menuName}")]
        public IActionResult MenuPermission(string menuName)
        {
            var roleId = Convert.ToInt32(HttpContext.Items["RoleId"]);

            return Ok(_roleService.CheckMenuPermission(roleId, menuName));
        }


        [HttpGet("GetControllers/{roleId}")]
        [DisplayName("Permission Setup")]
        [PermissionKey("Admin.Role.PermissionSetup")]
        public IActionResult GetControllers(int roleId)
        {
            return Ok(_roleService.GetControllers(roleId));
        }


        [HttpPost("SavePermission")]
        [DisplayName("Save Permission")]
        [PermissionKey("Admin.Role.SavePermission")]
        public IActionResult SavePermission([FromBody] RolePermissionReq permissionReq)
        {
            _roleService.SavePermission(permissionReq);

            return Ok();
        }
        */

        #endregion
    }
}
