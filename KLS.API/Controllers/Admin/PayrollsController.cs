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
    [Display(Name = "Payroll Management", GroupName = "Employee")]
    public class PayrollsController : BaseController
    {
        #region --- Member(s) ---

        private readonly IPayrollDetailService _payrollDetailService;
        private readonly IVendorPaymentService _vendorPaymentService;

        #endregion

        #region --- Constructor(s) ---

        public PayrollsController(IPayrollDetailService payrollDetailService, IVendorPaymentService vendorPaymentService)
        {
            _payrollDetailService = payrollDetailService;
            _vendorPaymentService = vendorPaymentService;
        }

        #endregion

        #region --- Method(s) ---

        [HttpGet]
        [DisplayName("List Payrolls")]
        [PermissionKey("Employee.Payroll.List")]
        public IActionResult List([FromQuery] PayrollReq payrollReq)
        {
            return Ok(_payrollDetailService.GetPagedList(payrollReq));
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
            _payrollDetailService.InjectEmp(injectEmpReq);
            return Ok();
        }


        [HttpPost("Inject/{vendorPaymentId}")]
        public IActionResult Inject(int vendorPaymentId)
        {
            _payrollDetailService.Inject(vendorPaymentId);

            return Ok();
        }


        [HttpPost]
        [DisplayName("Create/Update Payroll")]
        [PermissionKey("Employee.Payroll.Save")]
        public IActionResult Save([FromBody] PayrollReq payrollReq)
        {
            //_payrollDetailService.SavePayroll(payrollReq);
            return Ok();
        }


        [HttpDelete("{vendorPaymentId}")]
        [DisplayName("Delete Payroll")]
        [PermissionKey("Employee.Payroll.Delete")]
        public IActionResult Delete(int vendorPaymentId)
        {
            _payrollDetailService.Delete(vendorPaymentId);
            return Ok();
        }


        [HttpPost("Import")]
        [DisplayName("Import Payroll")]
        [PermissionKey("Employee.Payroll.Import")]
        public IActionResult Import([FromForm] IFormFile PayrollFile)
        {
            var response = _payrollDetailService.Import(PayrollFile);

            if (!string.IsNullOrEmpty(response.Error))
                return Conflict(response.Error);

            return Ok(response.ImportCount);
        }


        [HttpPost("VoidCheck/{vendorPaymentId}")]
        public IActionResult VoidCheck(int vendorPaymentId)
        {
            _payrollDetailService.VoidCheck(vendorPaymentId);

            return Ok();
        }


        [HttpPost("UnVoidCheck/{vendorPaymentId}")]
        public IActionResult UnVoidCheck(int vendorPaymentId)
        {
            _vendorPaymentService.UnVoidCheck(vendorPaymentId);

            return Ok();
        }

        #endregion
    }
}
