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
        [DisplayName("List User Role")]
        public IActionResult GetAll()
        {
            return Ok(_roleService.GetAllRoles());
        }


        [HttpGet("{id}")]
        public IActionResult GetById(int id)
        {
            var role = _roleService.GetRoleById(id);

            if (role == null)
                return NotFound($"User role with ID {id} not found.");

            return Ok(role);
        }


        [HttpPost]
        [DisplayName("Create User Role")]
        public IActionResult Create([FromBody] UserRole role)
        {
            if (_roleService.RoleNameExists(role))
                return Conflict("Rolename already exists.");

            var created = _roleService.CreateRole(role);

            return Ok(created);
        }


        [HttpPut]
        [DisplayName("Update User Role")]
        public IActionResult Update([FromBody] UserRole role)
        {
            if (_roleService.RoleNameExists(role))
                return Conflict("Rolename already exists.");

            var updated = _roleService.UpdateRole(role);

            return Ok(updated);
        }


        [HttpDelete("{id:int}")]
        [DisplayName("Delete User Role")]
        public IActionResult Delete(int id)
        {
            var existing = _roleService.GetRoleById(id);

            if (existing == null)
                return NotFound($"User role with ID {id} not found.");

            _roleService.DeleteRole(id);

            return Ok();
        }

        #endregion
    }
}
