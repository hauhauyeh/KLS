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
    [Display(Name = "PayrollService Management", GroupName = "Admin")]
    public class PayrollServicesController : BaseController
    {
        #region --- Member(s) ---

        private readonly IPayrollServiceService _payrollServiceService;

        #endregion

        #region --- Constructor(s) ---

        public PayrollServicesController(IPayrollServiceService payrollServiceService)
        {
            _payrollServiceService = payrollServiceService;
        }

        #endregion

        #region --- Method(s) ---

        [HttpGet]
        [DisplayName("List PayrollServices")]
        public IActionResult List([FromQuery] PayrollServiceReq payrollServiceReq)
        {
            return Ok(_payrollServiceService.GetPayrollService(payrollServiceReq));
        }

        #endregion
    }
}
