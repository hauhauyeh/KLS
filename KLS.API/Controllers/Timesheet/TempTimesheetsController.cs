using KLS.Contract.Services;
using KLS.Models;
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel.DataAnnotations;

namespace KLS.API.Controllers.Timesheet
{
    [Route("api/timesheet/[controller]")]
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
            return Ok(_tempTimesheetService.GetList(timesheetId));
        }


        [HttpPost]
        public IActionResult Create([FromBody] TempTimesheet tempTimesheet)
        {
            return Ok(_tempTimesheetService.Create(tempTimesheet));
        }


        [HttpPut]
        public IActionResult Update([FromBody] TempTimesheet tempTimesheet)
        {
            return Ok(_tempTimesheetService.Update(tempTimesheet));
        }


        [HttpDelete("{id}")]
        public IActionResult Delete(int id)
        {
            _tempTimesheetService.Delete(id);

            return Ok();
        }

        #endregion
    }
}
