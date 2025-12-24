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
    [Display(Name = "Advance Payment Management", GroupName = "Employee")]
    public class EmpAdvancesController : BaseController
    {
        #region --- Member(s) ---

        private readonly IEmpAdvanceService _empAdvanceService;

        #endregion

        #region --- Constructor(s) ---

        public EmpAdvancesController(IEmpAdvanceService empAdvanceService)
        {
            _empAdvanceService = empAdvanceService;
        }

        #endregion

        #region --- Method(s) ---

        [HttpGet]
        [DisplayName("List Advance Payment")]
        public IActionResult List([FromQuery] EmpAdvanceReq empAdvanceReq)
        {
            return Ok(_empAdvanceService.GetPagedList(empAdvanceReq));
        }


        [HttpGet("{id}")]
        public IActionResult GetById(int id)
        {
            return Ok(_empAdvanceService.GetById(id));
        }


        [HttpPost("Save")]
        [DisplayName("Save Advance Payment")]
        public IActionResult Save([FromBody] EmpAdvance empAdvance)
        {
            return Ok(_empAdvanceService.Save(empAdvance));
        }


        [HttpDelete("{id}")]
        [DisplayName("Delete Advance Payment")]
        public IActionResult Delete(int id)
        {
            _empAdvanceService.Delete(id);
            return Ok();
        }

        #endregion
    }
}
