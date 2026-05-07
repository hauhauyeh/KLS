using KLS.Contract.Services;
using KLS.Models;
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel.DataAnnotations;

namespace KLS.API.Controllers.Timesheet
{
    [Route("api/timesheet/[controller]")]
    [Display(Name = "Timesheet Management", GroupName = "Employee")]
    public class TimesheetsController : BaseController
    {
        #region --- Member(s) ---

        private readonly ITimesheetService _timesheetService;
        private readonly ISalesService _salesService;

        #endregion

        #region --- Constructor(s) ---

        public TimesheetsController(ITimesheetService timesheetService, ISalesService salesService)
        {
            _timesheetService = timesheetService;
            _salesService = salesService;
        }

        #endregion

        #region --- Method(s) ---

        [HttpGet("{timesheetId}")]
        public IActionResult GetById(int timesheetId)
        {
            return Ok(_timesheetService.GetById(timesheetId));
        }


        [HttpPost("Inject/{timesheetId}")]
        public IActionResult Inject(int timesheetId, [FromQuery] bool isClone)
        {
            _timesheetService.Inject(timesheetId, isClone);

            return Ok();
        }


        [HttpGet("validate/{SSNNumber}")]
        public IActionResult Validate(string SSNNumber)
        {
            if (string.IsNullOrWhiteSpace(SSNNumber) || SSNNumber.Length != 4)
            {
                return BadRequest("Please enter the last 4 digits of the SSN.");
            }

            var result = _timesheetService.Validate(SSNNumber);

            if (result != null)
            {
                return Ok(result);
            }

            return BadRequest("Please enter a valid SSN Number.");
        }


        [HttpPost("CheckInOut")]
        public IActionResult CheckInOut([FromBody] CheckInOutReq checkInOutReq)
        {
            return Ok(_timesheetService.CheckInOut(checkInOutReq));
        }


        [HttpGet("GetShipRoutes/{ShipDate}")]
        public IActionResult GetShipRoutes(DateOnly ShipDate)
        {
            return Ok(_salesService.GetShipRoutes(ShipDate));
        }

        #endregion
    }
}
