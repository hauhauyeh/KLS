using KLS.API.Helpers;
using KLS.Contract.Services;
using Microsoft.AspNetCore.Mvc;

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
        public IActionResult List()
        {
            return Ok(_payrollServiceTypeService.GetList());
        }

        #endregion
    }
}
