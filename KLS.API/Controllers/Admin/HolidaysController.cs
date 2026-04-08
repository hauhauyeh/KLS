using KLS.API.Helpers;
using KLS.Contract.Services;
using KLS.Models;
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
        [DisplayName("List Holidays")]
        [PermissionKey("Admin.Holiday.List")]
        public IActionResult List()
        {
            return Ok(_holidayService.GetList());
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
        [PermissionKey("Admin.Holiday.Create")]
        public IActionResult Create([FromBody] Holiday holiday)
        {
            if (_holidayService.NameExists(holiday))
                return Conflict("Holiday name already exists");

            return Ok(_holidayService.Create(holiday));
        }


        [HttpPut]
        [DisplayName("Update Holiday")]
        [PermissionKey("Admin.Holiday.Update")]
        public IActionResult Update([FromBody] Holiday holiday)
        {
            if (_holidayService.NameExists(holiday))
                return Conflict("Holiday name already exists");

            return Ok(_holidayService.Update(holiday));
        }


        [HttpDelete("{id}")]
        [DisplayName("Delete Holiday")]
        [PermissionKey("Admin.Holiday.Delete")]
        public IActionResult Delete(int id)
        {
            _holidayService.Delete(id);
            return Ok();
        }

        #endregion
    }
}
