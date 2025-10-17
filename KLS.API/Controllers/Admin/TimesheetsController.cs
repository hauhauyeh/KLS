using KLS.API.Helpers;
using KLS.Models;
using KLS.Services;
using KLS.Services.Interfaces;
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel;
using System.ComponentModel.DataAnnotations;
using System.Runtime.CompilerServices;

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

        [HttpGet]
        [DisplayName("Timesheet List")]
        public IActionResult List([FromQuery] TimesheetReq timesheetReq)
        {
            return Ok(_timesheetService.GetAllTimesheets(timesheetReq));
        }


        [HttpGet("Weekly")]
        public IActionResult Weekly([FromQuery] TimesheetReq timesheetReq)
        {
            return Ok(_timesheetService.GetWeeklyTimesheets(timesheetReq));
        }


        [HttpGet("{timesheetId}")]
        public IActionResult GetById(int timesheetId)
        {
            return Ok(_timesheetService.GetById(timesheetId));
        }


        [HttpPost]
        [DisplayName("Save Timesheet")]
        public IActionResult Save([FromBody] Timesheet timeSheet)
        {
            if (_timesheetService.ValidateTime(timeSheet))
                return Conflict("Out Time must be greater than In Time.");

            return Ok(_timesheetService.SaveTimesheet(timeSheet));
        }


        [HttpDelete("{timesheetId}")]
        [DisplayName("Delete Timesheet")]
        public IActionResult Delete(int timesheetId)
        {
            _timesheetService.DeleteTimesheet(timesheetId);

            return Ok();
        }


        [HttpPost("Inject/{timesheetId}")]
        public IActionResult Inject(int timesheetId, [FromQuery] bool isClone)
        {
            _timesheetService.InjectTimesheet(timesheetId, isClone);

            return Ok();
        }


        [HttpGet("GetPayPeriod")]
        public IActionResult GetPayPeriod()
        {
            return Ok(_timesheetService.GetPayPeriod());
        }

        #endregion
    }
}
