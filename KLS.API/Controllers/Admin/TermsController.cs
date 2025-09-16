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
    [Display(Name = "Term Management", GroupName = "Admin")]
    public class TermsController : BaseController
    {
        #region --- Member(s) ---

        private readonly ITermService _termService;

        #endregion

        #region --- Constructor(s) ---

        public TermsController(ITermService termService)
        {
            _termService = termService;
        }

        #endregion

        #region --- Method(s) ---

        [HttpGet]
        [DisplayName("List Terms")]
        public IActionResult List()
        {
            return Ok(_termService.GetAllTerms());
        }


        [HttpGet("Active")]
        public IActionResult GetActive()
        {
            return Ok(_termService.GetActiveTerms());
        }


        [HttpGet("{id}")]
        public IActionResult GetById(int id)
        {
            return Ok(_termService.GetById(id));
        }


        [HttpPost]
        [DisplayName("Create Term")]
        public IActionResult Create([FromBody] Term term)
        {
            if (_termService.ExistsName(term))
                return Conflict("TermName already exists");

            return Ok(_termService.CreateTerm(term));
        }


        [HttpPut]
        [DisplayName("Update Term")]
        public IActionResult Update([FromBody] Term term)
        {
            if (_termService.ExistsName(term))
                return Conflict("TermName already exists");

            return Ok(_termService.UpdateTerm(term));
        }


        [HttpDelete("{id}")]
        [DisplayName("Delete Term")]
        public IActionResult Delete(int id)
        {
            if (_termService.TermUsed(id))
                return Conflict("You can't delete. it is assigned to payee.");

            _termService.DeleteTerm(id);

            return Ok();
        }

        #endregion
    }
}
