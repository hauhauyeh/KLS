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
        [PermissionKey("Admin.Term.List")]
        public IActionResult List()
        {
            return Ok(_termService.GetList());
        }


        [HttpGet("Active")]
        public IActionResult GetActive()
        {
            return Ok(_termService.GetActive());
        }


        [HttpGet("{id}")]
        public IActionResult GetById(int id)
        {
            return Ok(_termService.GetById(id));
        }


        [HttpPost]
        [DisplayName("Create Term")]
        [PermissionKey("Admin.Term.Create")]
        public IActionResult Create([FromBody] Term term)
        {
            return Ok(_termService.Create(term));
        }


        [HttpPut]
        [DisplayName("Update Term")]
        [PermissionKey("Admin.Term.Update")]
        public IActionResult Update([FromBody] Term term)
        {
            return Ok(_termService.Update(term));
        }


        [HttpDelete("{id}")]
        [DisplayName("Delete Term")]
        [PermissionKey("Admin.Term.Delete")]
        public IActionResult Delete(int id)
        {
            _termService.Delete(id);

            return Ok();
        }

        #endregion
    }
}
