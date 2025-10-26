using KLS.API.Helpers;
using KLS.Common;
using KLS.Models;
using KLS.Services;
using KLS.Services.Interfaces;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using System.ComponentModel;
using System.ComponentModel.DataAnnotations;

namespace KLS.API.Controllers.Admin
{
    [AuthorizeAdmin]
    [Route("api/admin/[controller]")]
    [Display(Name = "Payroll Management", GroupName = "Employee")]
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


        [HttpGet("{vendorPaymentId}")]
        public IActionResult GetById(int vendorPaymentId)
        {
            //return Ok(_payrollDetailService.GetById(vendorPaymentId));
            return Ok();
        }


        [HttpPost("InjectEmp")]
        public IActionResult InjectEmp([FromBody] PayrollInjectEmpReq injectEmpReq)
        {
            _payrollDetailService.InjectPayrollEmp(injectEmpReq);
            return Ok();
        }


        [HttpPost("Inject/{vendorPaymentId}")]
        public IActionResult Inject(int vendorPaymentId)
        {
            _payrollDetailService.InjectPayroll(vendorPaymentId);

            return Ok();
        }


        //[HttpPost]
        //[DisplayName("Save Payroll")]
        //public IActionResult Save([FromBody] PayrollReq payrollReq)
        //{
        //    _payrollDetailService.SavePayroll(payrollReq);
        //    return Ok();
        //}


        [HttpDelete("{vendorPaymentId}")]
        [DisplayName("Delete Payroll")]
        public IActionResult Delete(int vendorPaymentId)
        {
            _payrollDetailService.DeletePayroll(vendorPaymentId);
            return Ok();
        }


        [HttpPost("Import")]
        [DisplayName("Import Payroll")]
        public IActionResult Import([FromForm] IFormFile PayrollFile)
        {
            var response = _payrollDetailService.Import(PayrollFile);

            if (!string.IsNullOrEmpty(response.Error))
                return Conflict(response.Error);

            return Ok(response.ImportCount);
        }

        #endregion
    }
}
