using KLS.API.Helpers;
using KLS.Services.Interfaces;
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel.DataAnnotations;

namespace KLS.API.Controllers.Admin
{
    [AuthorizeAdmin]
    [Route("api/admin/[controller]")]
    [Display(Name = "TempPayroll Management", GroupName = "Admin")]
    public class TempPayrollDetailsController : BaseController
    {
        #region --- Member(s) ---

        private readonly ITempPayrollDetailService _tempPayrollService;

        #endregion

        #region --- Constructor(s) ---

        public TempPayrollDetailsController(ITempPayrollDetailService tempPayrollService)
        {
            _tempPayrollService = tempPayrollService;
        }

        #endregion

        #region --- Method(s) ---



        #endregion
    }
}
