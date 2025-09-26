using KLS.API.Helpers;
using KLS.Services.Interfaces;
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel.DataAnnotations;

namespace KLS.API.Controllers.Admin
{
    [AuthorizeAdmin]
    [Route("api/admin/[controller]")]
    [Display(Name = "PayrollServiceType Management", GroupName = "Admin")]
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



        #endregion
    }
}
