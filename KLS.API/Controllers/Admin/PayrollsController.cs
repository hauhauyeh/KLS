using KLS.API.Helpers;
using KLS.Common;
using KLS.Models;
using KLS.Services;
using KLS.Services.Interfaces;
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel;
using System.ComponentModel.DataAnnotations;

namespace KLS.API.Controllers.Admin
{
    //[AuthorizeAdmin]
    [Route("api/admin/[controller]")]
    [Display(Name = "Payroll Management", GroupName = "Admin")]
    public class PayrollsController : BaseController
    {
        #region --- Member(s) ---

        private readonly IPayrollDetailService _payrollDetailService;

        #endregion

        #region --- Constructor(s) ---

        public PayrollsController(IPayrollDetailService payrollDetailService)
        {
            _payrollDetailService = payrollDetailService;
        }

        #endregion

        #region --- Method(s) ---

        [HttpGet]
        [DisplayName("List Payroll")]
        public IActionResult List([FromQuery] PayrollReq payrollReq)
        {
            return Ok(_payrollDetailService.GetAllPayrolls(payrollReq));
        }


        [HttpPost("Inject/{vendorPaymentId}")]
        public IActionResult Inject(int vendorPaymentId)
        {
            _payrollDetailService.InjectPayrollDetail(vendorPaymentId);

            return Ok();
        }


        [HttpPost("Import")]
        [DisplayName("Import Payroll")]
        public IActionResult Import([FromForm] IFormFile PayrollFile)
        {
            var RecordCount = _payrollDetailService.Import(PayrollFile);

            return Ok(RecordCount);
        }

        #endregion
    }
}
