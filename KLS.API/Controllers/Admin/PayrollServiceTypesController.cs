using KLS.API.Helpers;
using KLS.Services.Interfaces;
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel.DataAnnotations;

namespace KLS.API.Controllers.Admin
{
    [AuthorizeAdmin]
    [Route("api/admin/[controller]")]
    public class PayrollServiceTypesController : BaseController
    {
        #region --- Member(s) ---

        private readonly IPayrollServiceTypeService _payrollServiceTypeService;

        #endregion

        #region --- Constructor(s) ---

        public PayrollServiceTypesController(IPayrollServiceTypeService payrollServiceTypeService)
        {
            _payrollServiceTypeService = payrollServiceTypeService;
        }

        #endregion

        #region --- Method(s) ---

        [HttpGet]
        public IActionResult GetServiceTypes()
        {
            return Ok(_payrollServiceTypeService.GetServiceTypes());
        }

        #endregion
    }
}
