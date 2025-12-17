using KLS.API.Helpers;
using KLS.Contract.Services;
using KLS.Models;
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel.DataAnnotations;

namespace KLS.API.Controllers.Admin
{
    [AuthorizeAdmin]
    [Route("api/admin/[controller]")]
    [Display(Name = "Temp Timesheet Management", GroupName = "Employee")]
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

        [HttpGet("{timesheetId}")]
        public IActionResult List(int timesheetId)
        {
            return Ok(_tempTimesheetService.GetTempTimesheetList(timesheetId));
        }


        [HttpPost]
        public IActionResult Create([FromBody] TempTimesheet tempTimesheet)
        {
            return Ok(_tempTimesheetService.CreateTempTimesheet(tempTimesheet));
        }


        [HttpPut]
        public IActionResult Update([FromBody] TempTimesheet tempTimesheet)
        {
            return Ok(_tempTimesheetService.UpdateTempTimesheet(tempTimesheet));
        }


        [HttpDelete("{id}")]
        public IActionResult Delete(int id)
        {
            _tempTimesheetService.DeleteTempTimesheet(id);

            return Ok();
        }

        #endregion
    }
}
