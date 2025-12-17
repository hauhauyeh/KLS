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
    [Display(Name = "Advance Payment Management", GroupName = "Employee")]
    public class EmployeeAdvancePmtsController : BaseController
    {
        #region --- Member(s) ---

        private readonly IEmployeeAdvancePmtService _employeeAdvancePmt;

        #endregion

        #region --- Constructor(s) ---

        public EmployeeAdvancePmtsController(IEmployeeAdvancePmtService employeeAdvancePmt)
        {
            _employeeAdvancePmt = employeeAdvancePmt;
        }

        #endregion

        #region --- Method(s) ---

        [HttpGet]
        [DisplayName("List EmpAdvancePmt")]
        public IActionResult List([FromQuery] EmployeeAdvancePmtReq empAdvanceReq)
        {
            return Ok(_employeeAdvancePmt.GetAllEmployeeAdvancePmt(empAdvanceReq));
        }


        [HttpGet("{id}")]
        public IActionResult GetById(int id)
        {
            return Ok(_employeeAdvancePmt.GetById(id));
        }


        [HttpPost("Save")]
        [DisplayName("Save EmpAdvancePmt")]
        public IActionResult Save([FromBody] EmployeeAdvancePmt employeeAdvancePmt)
        {
            return Ok(_employeeAdvancePmt.SaveEmployeeAdvancePmt(employeeAdvancePmt));
        }


        [HttpDelete("{id}")]
        [DisplayName("Delete EmpAdvancePmt")]
        public IActionResult Delete(int id)
        {
            _employeeAdvancePmt.Delete(id);
            return Ok();
        }

        #endregion
    }
}
