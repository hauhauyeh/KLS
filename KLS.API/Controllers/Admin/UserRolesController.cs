using KLS.API.Helpers;
using KLS.Models;
using KLS.Services;
using KLS.Services.Interfaces;
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel;
using System.ComponentModel.DataAnnotations;

namespace KLS.API.Controllers.Admin
{
    [AuthorizeAdmin]
    [Route("api/admin/[controller]")]
    [Display(Name = "Role Management", GroupName = "Admin")]
    public class UserRolesController : BaseController
    {
        #region --- Member(s) ---

        private readonly IUserRoleService _roleService;

        #endregion

        #region --- Constructor(s) ---

        public UserRolesController(IUserRoleService roleService)
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
        public IActionResult Create([FromBody] UserRole role)
        {
            if (_roleService.RoleNameExists(role))
                return Conflict("Rolename already exists.");

            var created = _roleService.CreateRole(role);

            return Ok(created);
        }


        [HttpPut]
        [DisplayName("Update Role")]
        public IActionResult Update([FromBody] UserRole role)
        {
            if (_roleService.RoleNameExists(role))
                return Conflict("Rolename already exists.");

            var updated = _roleService.UpdateRole(role);

            return Ok(updated);
        }


        [HttpDelete("{id:int}")]
        [DisplayName("Delete Role")]
        public IActionResult Delete(int id)
        {
            var existing = _roleService.GetById(id);

            if (existing == null)
                return NotFound($"User role with ID {id} not found.");

            _roleService.DeleteRole(id);

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

        #endregion
    }
}
