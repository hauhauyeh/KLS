using KLS.API.Helpers;
using KLS.Services.Interfaces;
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel.DataAnnotations;

namespace KLS.API.Controllers.Admin
{
    [AuthorizeAdmin]
    [Route("api/admin/[controller]")]
    [Display(Name = "PayrollDetail Management", GroupName = "Admin")]
    public class PayrollDetailsController : BaseController
    {
        #region --- Member(s) ---

        private readonly IPayrollDetailService _payrollDetailService;

        #endregion

        #region --- Constructor(s) ---

        public PayrollDetailsController(IPayrollDetailService payrollDetailService)
        {
            _payrollDetailService = payrollDetailService;
        }

        #endregion

        #region --- Method(s) ---



        #endregion
    }
}
