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
    [AuthorizeAdmin]
    [Route("api/admin/[controller]")]
    [Display(Name = "Payroll Service Management", GroupName = "Employee")]
    public class PayrollServicesController : BaseController
    {
        #region --- Member(s) ---

        private readonly IPayrollServiceService _payrollService;
        private readonly ISystemSettingService _systemSettingService;

        #endregion

        #region --- Constructor(s) ---

        public PayrollServicesController(IPayrollServiceService payrollService, ISystemSettingService systemSettingService)
        {
            _payrollService = payrollService;
            _systemSettingService = systemSettingService;
        }

        #endregion

        #region --- Method(s) ---

        [HttpGet]
        [DisplayName("List Payroll Service")]
        public IActionResult List([FromQuery] PayrollServiceReq payrollServiceReq)
        {
            return Ok(_payrollService.GetAllPayrollService(payrollServiceReq));
        }


        [HttpGet("{payrollId}")]
        public IActionResult GetById(int payrollId)
        {
            var payrollService = new PayrollService();

            if (payrollId > 0)
                payrollService = _payrollService.GetById(payrollId);
            else
                payrollService.FromAccountId = _systemSettingService.GetByKey<int>(GlobalKey.PAYROLL_DEFAULT_BANK);

            return Ok(payrollService);
        }


        [HttpPost]
        [DisplayName("Save Payroll Service")]
        public IActionResult Save([FromBody] PayrollService payrollService)
        {
            return Ok(_payrollService.SavePayrollService(payrollService));
        }


        [HttpDelete("{payrollId}")]
        [DisplayName("Delete Payroll Service")]
        public IActionResult Delete(int payrollId)
        {
            _payrollService.DeletePayrollService(payrollId);
            return Ok();
        }


        [HttpPost("Inject/{payrollServiceId}")]
        public IActionResult Inject(int payrollServiceId, [FromQuery] bool isClone)
        {
            _payrollService.InjectPayrollService(payrollServiceId, isClone);

            return Ok();
        }


        [HttpPost("InjectEmployee")]
        public IActionResult InjectEmployee()
        {
            _payrollService.InjectEmployee();
            return Ok();
        }

        #endregion
    }
}
