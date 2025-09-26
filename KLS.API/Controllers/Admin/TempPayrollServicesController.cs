using KLS.API.Helpers;
using KLS.Services.Interfaces;
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel.DataAnnotations;

namespace KLS.API.Controllers.Admin
{
    [AuthorizeAdmin]
    [Route("api/admin/[controller]")]
    [Display(Name = "TempPayrollService Management", GroupName = "Admin")]
    public class TempPayrollServicesController : BaseController
    {
        #region --- Member(s) ---

        private readonly ITempPayrollServiceService _empPayrollServiceService;

        #endregion

        #region --- Constructor(s) ---

        public TempPayrollServicesController(ITempPayrollServiceService empPayrollServiceService)
        {
            _empPayrollServiceService = empPayrollServiceService;
        }

        #endregion

        #region --- Method(s) ---



        #endregion
    }
}
