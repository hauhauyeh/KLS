using KLS.API.Helpers;
using KLS.Models;
using KLS.Services.Interfaces;
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel;
using System.ComponentModel.DataAnnotations;

namespace KLS.API.Controllers.Admin
{
    [AuthorizeAdmin]
    [Route("api/admin/[controller]")]
    [Display(Name = "Unit Management", GroupName = "Admin")]
    public class UnitsController : BaseController
    {
        #region --- Member(s) ---

        private readonly IUnitService _unitService;

        #endregion

        #region --- Constructor(s) ---

        public UnitsController(IUnitService unitService)
        {
            _unitService = unitService;
        }

        #endregion

        #region --- Method(s) ---

        [HttpGet]
        [DisplayName("List Unit")]
        public IActionResult List()
        {
            return Ok(_unitService.GetAllUnits());
        }


        [HttpGet("{id}")]
        public IActionResult GetById(int id)
        {
            return Ok(_unitService.GetById(id));
        }


        [HttpPost]
        [DisplayName("Create Unit")]
        public IActionResult Create([FromBody] Unit unit)
        {
            if (_unitService.ExistsCode(unit))
                return Conflict("Code already exists");

            if (_unitService.ExistsName(unit))
                return Conflict("Name already exists");

            return Ok(_unitService.CreateUnit(unit));
        }


        [HttpPut]
        [DisplayName("Update Unit")]
        public IActionResult Update([FromBody] Unit unit)
        {
            if (_unitService.ExistsCode(unit))
                return Conflict("Code already exists");

            if (_unitService.ExistsName(unit))
                return Conflict("Name already exists");

            return Ok(_unitService.UpdateUnit(unit));
        }


        [HttpDelete("{id}")]
        [DisplayName("Delete Unit")]
        public IActionResult Delete(int id)
        {
            _unitService.DeleteUnit(id);

            return Ok();
        }

        #endregion
    }
}
