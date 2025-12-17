using KLS.API.Helpers;
using KLS.Contract.Services;
using KLS.Models;
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel;
using System.ComponentModel.DataAnnotations;

namespace KLS.API.Controllers.Admin
{
    [AuthorizeAdmin]
    [Route("api/admin/[controller]")]
    [Display(Name = "Role Management", GroupName = "Admin")]
    public class RolesController : BaseController
    {
        #region --- Member(s) ---

        private readonly ISystemRoleService _roleService;

        #endregion

        #region --- Constructor(s) ---

        public RolesController(ISystemRoleService roleService)
        {
            _roleService = roleService;
        }

        #endregion

        #region --- Method(s) ---

        [HttpGet]
        [DisplayName("List Role")]
        public IActionResult List()
        {
            return Ok(_roleService.GetAllRoles());
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
        public IActionResult Create([FromBody] SystemRole role)
        {
            if (_roleService.RoleNameExists(role))
                return Conflict("Rolename already exists.");

            var created = _roleService.CreateRole(role);

            return Ok(created);
        }


        [HttpPut]
        [DisplayName("Update Role")]
        public IActionResult Update([FromBody] SystemRole role)
        {
            if (_roleService.RoleNameExists(role))
                return Conflict("Rolename already exists.");

            var updated = _roleService.UpdateRole(role);

            return Ok(updated);
        }


        [HttpDelete("{roleId}")]
        [DisplayName("Delete Role")]
        public IActionResult Delete(int roleId)
        {
            var existing = _roleService.GetById(roleId);

            if (existing == null)
                return NotFound($"User role with ID {roleId} not found.");

            if (_roleService.RoleUsed(roleId))
                return Conflict("This Role can't be deleted as it is linked to an employee.");

            _roleService.DeleteRole(roleId);

            return Ok();
        }


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
        public IActionResult GetControllers(int roleId)
        {
            return Ok(_roleService.GetControllers(roleId));
        }


        [HttpPost("SavePermission")]
        [DisplayName("Save Permission")]
        public IActionResult SavePermission([FromBody] RolePermissionReq permissionReq)
        {
            _roleService.SavePermission(permissionReq);

            return Ok();
        }

        #endregion
    }
}
