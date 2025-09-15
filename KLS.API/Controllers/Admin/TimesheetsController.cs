using KLS.API.Helpers;
using KLS.Services.Interfaces;
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel.DataAnnotations;

namespace KLS.API.Controllers.Admin
{
    [AuthorizeAdmin]
    [Route("api/admin/[controller]")]
    [Display(Name = "Timesheet Management", GroupName = "Employee")]
    public class TimesheetsController : BaseController
    {
        #region --- Member(s) ---

        private readonly ITimesheetService _timesheetService;

        #endregion

        #region --- Constructor(s) ---

        public TimesheetsController(ITimesheetService timesheetService)
        {
            _timesheetService = timesheetService;
        }

        #endregion

        #region --- Method(s) ---



        #endregion
    }
}
