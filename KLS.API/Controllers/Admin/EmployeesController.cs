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
    [Display(Name = "Employee Management", GroupName = "Employee")]
    public class EmployeesController : BaseController
    {
        #region --- Member(s) ---

        private readonly IEmployeeService _employeeService;
        private readonly ISystemUserService _userService;
        private readonly ISystemRoleService _roleService;

        #endregion

        #region --- Constructor(s) ---

        public EmployeesController(IEmployeeService employeeService, ISystemUserService userService, ISystemRoleService roleService)
        {
            _employeeService = employeeService;
            _userService = userService;
            _roleService = roleService;
        }

        #endregion

        #region --- Method(s) ---

        [HttpGet]
        [DisplayName("List Employees")]
        [PermissionKey("Employee.Employee.List")]
        public IActionResult List([FromQuery] EmpReq empReq)
        {
            return Ok(_employeeService.GetPagedList(empReq));
        }


        [HttpGet("Active")]
        public IActionResult GetActive()
        {
            return Ok(_employeeService.GetActive());
        }


        [HttpGet("Drivers")]
        public IActionResult GetDrivers()
        {
            return Ok(_employeeService.GetDrivers());
        }


        [HttpGet("{id}")]
        public IActionResult GetById(int id)
        {
            var employee = _employeeService.GetById(id);

            if (employee == null)
                return NotFound($"Employee with Id {id} not found.");

            return Ok(employee);
        }


        [HttpPost]
        [DisplayName("Create Employee")]
        [PermissionKey("Employee.Employee.Create")]
        public IActionResult Create([FromBody] EmployeeDTO employeeDTO)
        {
            if (employeeDTO.RoleId > 0)
            {
                var targetRole = _roleService.GetById(employeeDTO.RoleId);
                if (targetRole != null && targetRole.IsAdmin && !IsCurrentUserAdmin())
                    return StatusCode(403, "Only super admin can assign admin roles.");
            }

            if (_employeeService.NameExists(employeeDTO))
                return Conflict("Employee name already exists.");

            if (!string.IsNullOrEmpty(employeeDTO.Username) && _userService.UserNameExists(employeeDTO.Username, employeeDTO.PayeeId))
                return Conflict("Username already exists");

            if (!string.IsNullOrWhiteSpace(employeeDTO.Email) && _userService.EmailExists(employeeDTO.Email.Trim(), employeeDTO.PayeeId))
                return Conflict("Email already exists");

            var created = _employeeService.Create(employeeDTO);

            return Ok(created);
        }


        [HttpPut]
        [DisplayName("Update Employee")]
        [PermissionKey("Employee.Employee.Update")]
        public IActionResult Update([FromBody] EmployeeDTO employeeDTO)
        {
            if (employeeDTO.RoleId > 0)
            {
                var targetRole = _roleService.GetById(employeeDTO.RoleId);
                if (targetRole != null && targetRole.IsAdmin && !IsCurrentUserAdmin())
                    return StatusCode(403, "Only super admin can assign admin roles.");
            }

            if (_employeeService.NameExists(employeeDTO))
                return Conflict("Employee name already exists.");

            if (!string.IsNullOrEmpty(employeeDTO.Username) && _userService.UserNameExists(employeeDTO.Username, employeeDTO.PayeeId))
                return Conflict("Username already exists");

            if (!string.IsNullOrWhiteSpace(employeeDTO.Email) && _userService.EmailExists(employeeDTO.Email.Trim(), employeeDTO.PayeeId))
                return Conflict("Email already exists");

            var updated = _employeeService.Update(employeeDTO);

            if (updated == null)
                return NotFound($"Employee with Id {employeeDTO.PayeeId} not found.");

            return Ok(updated);
        }


        [HttpDelete("{id}")]
        [DisplayName("Delete Employee")]
        [PermissionKey("Employee.Employee.Delete")]
        public IActionResult Delete(int id)
        {
            if (!_employeeService.Delete(id))
                return NotFound($"Employee with Id {id} not found.");

            return Ok();
        }


        [HttpGet("Search")]
        public IActionResult Search([FromQuery] PayeeSearchReq searchReq)
        {
            return Ok(_employeeService.Search(searchReq));
        }

        #endregion
    }
}
