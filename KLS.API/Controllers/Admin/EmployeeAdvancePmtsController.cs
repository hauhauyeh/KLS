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
    [Display(Name = "Company Management", GroupName = "Admin")]
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

        #endregion
    }
}
