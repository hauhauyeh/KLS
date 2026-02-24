using KLS.API.Helpers;
using KLS.Common;
using KLS.Contract.Services;
using KLS.Models;
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
            return Ok(_payrollService.GetPagedList(payrollServiceReq));
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
        [DisplayName("Create/Update Payroll Service")]
        public IActionResult Save([FromBody] PayrollService payrollService)
        {
            return Ok(_payrollService.Save(payrollService));
        }


        [HttpDelete("{payrollId}")]
        [DisplayName("Delete Payroll Service")]
        public IActionResult Delete(int payrollId)
        {
            _payrollService.Delete(payrollId);
            return Ok();
        }


        [HttpPost("Inject/{payrollServiceId}")]
        public IActionResult Inject(int payrollServiceId, [FromQuery] bool isClone)
        {
            _payrollService.Inject(payrollServiceId, isClone);

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
