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

        [HttpGet("{timesheetId}")]
        public IActionResult GetById(int timesheetId)
        {
            return Ok(_timesheetService.GetById(timesheetId));
        }


        [HttpPost]
        [DisplayName("Save Timesheet")]
        public IActionResult Save([FromBody] Timesheet timeSheet)
        {
            return Ok(_timesheetService.SaveTimesheet(timeSheet));
        }


        [HttpDelete("{timesheetId}")]
        [DisplayName("Delete Timesheet")]
        public IActionResult Delete(int timesheetId)
        {
            _timesheetService.DeleteTimesheet(timesheetId);

            return Ok();
        }

        #endregion
    }
}
