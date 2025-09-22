using KLS.Models;
using KLS.Services;
using KLS.Services.Interfaces;
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel;
using System.ComponentModel.DataAnnotations;

namespace KLS.API.Controllers.Admin
{
    [Route("api/admin/[controller]")]
    [Display(Name = "Employee Management", GroupName = "Admin")]
    public class EmployeesController : BaseController
    {
        #region --- Member(s) ---

        private readonly IEmployeeService _employeeService;
        private readonly ISystemUserService _userService;

        #endregion

        #region --- Constructor(s) ---

        public EmployeesController(IEmployeeService employeeService, ISystemUserService userService)
        {
            _employeeService = employeeService;
            _userService = userService;
        }

        #endregion

        #region --- Method(s) ---

        [HttpGet]
        [DisplayName("List Employees")]
        public IActionResult List([FromQuery] EmpReq empReq)
        {
            return Ok(_employeeService.GetAllEmployees(empReq));
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
        public IActionResult Create([FromBody] EmployeeDTO employeeDTO)
        {
            if (_employeeService.EmployeeExists(employeeDTO))
                return Conflict("Employee name already exists.");

            if (!string.IsNullOrEmpty(employeeDTO.Username) && _userService.UserNameExists(employeeDTO.Username, employeeDTO.PayeeId))
                return Conflict("Username already exists");

            var created = _employeeService.CreateEmployee(employeeDTO);

            return Ok(created);
        }


        [HttpPut]
        [DisplayName("Update Employee")]
        public IActionResult Update([FromBody] EmployeeDTO employeeDTO)
        {
            if (_employeeService.EmployeeExists(employeeDTO))
                return Conflict("Employee name already exists.");

            if (!string.IsNullOrEmpty(employeeDTO.Username) && _userService.UserNameExists(employeeDTO.Username, employeeDTO.PayeeId))
                return Conflict("Username already exists");

            var updated = _employeeService.UpdateEmployee(employeeDTO);

            return Ok(updated);
        }


        [HttpDelete("{id}")]
        [DisplayName("Delete Employee")]
        public IActionResult Delete(int id)
        {
            _employeeService.DeleteEmployee(id);

            return Ok();
        }


        [HttpGet("Search")]
        public IActionResult Search([FromQuery] PayeeSearchReq searchReq)
        {
            return Ok(_employeeService.SearchEmployee(searchReq));
        }

        #endregion
    }
}
