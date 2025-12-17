using KLS.API.Helpers;
using KLS.Contract.Services;
using KLS.Models;
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel.DataAnnotations;

namespace KLS.API.Controllers.Admin
{
    [AuthorizeAdmin]
    [Route("api/admin/[controller]")]
    [Display(Name = "Temp Payroll Management", GroupName = "Employee")]
    public class TempPayrollDetailsController : BaseController
    {
        #region --- Member(s) ---

        private readonly ITempPayrollDetailService _tempPayrollDetailService;

        #endregion

        #region --- Constructor(s) ---

        public TempPayrollDetailsController(ITempPayrollDetailService tempPayrollDetailService)
        {
            _tempPayrollDetailService = tempPayrollDetailService;
        }

        #endregion

        #region --- Method(s) ---

        [HttpGet]
        public IActionResult List([FromQuery] int vendorPaymentId)
        {
            return Ok(_tempPayrollDetailService.GetTempPayrollList(vendorPaymentId));
        }


        [HttpGet("{tempId}")]
        public IActionResult GetById(int tempId)
        {
            return Ok(_tempPayrollDetailService.GetById(tempId));
        }


        [HttpPut]
        public IActionResult Update([FromBody] TempPayrollDetail tempPayrollDetail)
        {
            return Ok(_tempPayrollDetailService.Update(tempPayrollDetail));
        }

        #endregion
    }
}
