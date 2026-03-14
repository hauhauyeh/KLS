using KLS.API.Helpers;
using KLS.Contract.Services;
using KLS.Models;
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel;
using System.ComponentModel.DataAnnotations;

namespace KLS.API.Controllers.Web
{
    [AuthorizeWeb]
    [Route("api/web/[controller]")]
    [Display(Name = "Role Management", GroupName = "Web")]
    public class UserRolesController : BaseController
    {
        #region --- Member(s) ---

        private readonly IUserRoleService _userRoleService;

        #endregion

        #region --- Constructor(s) ---

        public UserRolesController(IUserRoleService userRoleService)
        {
            _userRoleService = userRoleService;
        }

        #endregion

        #region --- Method(s) ---

        [HttpGet]
        [DisplayName("List Roles")]
        public IActionResult List()
        {
            return Ok(_userRoleService.GetAllUserRoles());
        }


        [HttpGet("{id}")]
        public IActionResult GetById(int id)
        {
            var role = _userRoleService.GetById(id);

            if (role == null)
                return NotFound($"User role with ID {id} not found.");

            return Ok(role);
        }


        [HttpPost]
        [DisplayName("Create Role")]
        public IActionResult Create([FromBody] UserRole userRole)
        {
            if (_userRoleService.UserRoleNameExists(userRole))
                return Conflict("Rolename already exists.");

            var created = _userRoleService.CreateUserRole(userRole);

            return Ok(created);
        }


        [HttpPut]
        [DisplayName("Update Role")]
        public IActionResult Update([FromBody] UserRole userRole)
        {
            if (_userRoleService.UserRoleNameExists(userRole))
                return Conflict("Rolename already exists.");

            var created = _userRoleService.UpdateUserRole(userRole);

            return Ok(created);
        }


        [HttpDelete("{roleId}")]
        [DisplayName("Delete Role")]
        public IActionResult Delete(int roleId)
        {
            var existing = _userRoleService.GetById(roleId);

            if (existing == null)
                return NotFound($"User role with ID {roleId} not found.");

            _userRoleService.DeleteUserRole(roleId);

            return Ok();
        }

        #endregion
    }
}
