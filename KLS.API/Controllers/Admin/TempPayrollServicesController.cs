using KLS.API.Helpers;
using KLS.Models;
using KLS.Services.Interfaces;
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel;
using System.ComponentModel.DataAnnotations;

namespace KLS.API.Controllers.Admin
{
    [AuthorizeAdmin]
    [Route("api/admin/[controller]")]
    [Display(Name = "Temp Payroll Service Management", GroupName = "Admin")]
    public class TempPayrollServicesController : BaseController
    {
        #region --- Member(s) ---

        private readonly ITempPayrollServiceService _tempService;

        #endregion

        #region --- Constructor(s) ---

        public TempPayrollServicesController(ITempPayrollServiceService tempService)
        {
            _tempService = tempService;
        }

        #endregion

        #region --- Method(s) ---

        [HttpGet]
        public IActionResult List([FromQuery] int payrollServiceId)
        {
            return Ok(_tempService.GetTempServiceList(payrollServiceId));
        }


        [HttpPost]
        public IActionResult Create([FromBody] TempPayrollService tempService)
        {
            return Ok(_tempService.Create(tempService));
        }


        [HttpPut]
        public IActionResult Update([FromBody] TempPayrollService tempService)
        {
            return Ok(_tempService.Update(tempService));
        }


        [HttpDelete("{tempId}")]
        public IActionResult Delete(int tempId)
        {
            _tempService.Delete(tempId);
            return Ok();
        }

        #endregion
    }
}
