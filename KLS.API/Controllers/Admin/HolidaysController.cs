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
    [Display(Name = "Holiday Management", GroupName = "Admin")]
    public class HolidaysController : BaseController
    {
        #region --- Member(s) ---

        private readonly IHolidayService _holidayService;

        #endregion

        #region --- Constructor(s) ---

        public HolidaysController(IHolidayService holidayService)
        {
            _holidayService = holidayService;
        }

        #endregion

        #region --- Method(s) ---

        [HttpGet]
        [DisplayName("List Holiday")]
        public IActionResult GetAll()
        {
            return Ok(_holidayService.GetAllHolidays());
        }


        [HttpGet("{id}")]
        public IActionResult GetById(int id)
        {
            var holiday = _holidayService.GetById(id);

            if (holiday == null)
                return NotFound($"Holiday with ID {id} not found.");

            return Ok(holiday);
        }


        [HttpPost]
        [DisplayName("Create Holiday")]
        public IActionResult Create([FromBody] Holiday holiday)
        {
            if (_holidayService.NameExists(holiday))
                return Conflict("Holiday name already exists");

            return Ok(_holidayService.CreateHoliday(holiday));
        }


        [HttpPut]
        [DisplayName("Update Holiday")]
        public IActionResult Update([FromBody] Holiday holiday)
        {
            if (_holidayService.NameExists(holiday))
                return Conflict("Holiday name already exists");

            return Ok(_holidayService.UpdateHoliday(holiday));
        }


        [HttpDelete("{id}")]
        [DisplayName("Delete Holiday")]
        public IActionResult Delete(int id)
        {
            _holidayService.DeleteHoliday(id);
            return Ok();
        }

        #endregion
    }
}
