using KLS.API.Helpers;
using KLS.Services.Interfaces;
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel.DataAnnotations;

namespace KLS.API.Controllers.Admin
{
    [AuthorizeAdmin]
    [Route("api/admin/[controller]")]
    [Display(Name = "TempTimesheet Management", GroupName = "Admin")]
    public class TempTimesheetsController : BaseController
    {
        #region --- Member(s) ---

        private readonly ITempTimesheetService _tempTimesheetService;

        #endregion

        #region --- Constructor(s) ---

        public TempTimesheetsController(ITempTimesheetService tempTimesheetService)
        {
            _tempTimesheetService = tempTimesheetService;
        }

        #endregion

        #region --- Method(s) ---



        #endregion
    }
}
