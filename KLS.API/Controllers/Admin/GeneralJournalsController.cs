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
    [Display(Name = "General Journal Management", GroupName = "Accounting")]
    public class GeneralJournalsController : BaseController
    {
        #region --- Member(s) ---

        private readonly IGeneralJournalService _gjService;

        #endregion

        #region --- Constructor(s) ---

        public GeneralJournalsController(IGeneralJournalService gjService)
        {
            _gjService = gjService;
        }

        #endregion

        #region --- Method(s) ---

        [HttpGet]
        [DisplayName("List General Journal")]
        public IActionResult List([FromQuery] GJReq gJReq)
        {
            return Ok(_gjService.GetAllGeneralJournals(gJReq));
        }


        [HttpGet("{id}")]
        public IActionResult GetById(int id)
        {
            var gj = _gjService.GetById(id);

            if (gj == null)
                return NotFound($"General journal not found.");

            return Ok(gj);
        }


        [HttpPost("Save")]
        [DisplayName("Add/Edit General Journal")]
        public IActionResult Save([FromBody] GeneralJournal generalJournal)
        {
            return Ok(_gjService.SaveGeneralJournal(generalJournal));
        }


        [HttpDelete("{id}")]
        [DisplayName("Delete General Journal")]
        public IActionResult Delete(int id)
        {
            _gjService.DeleteGeneralJournal(id);

            return Ok();
        }


        [HttpPost("UpdateNotes")]
        public IActionResult UpdateNotes([FromBody] GeneralJournal gj)
        {
            _gjService.UpdateNotes(gj);

            return Ok();
        }


        [HttpPost("Inject/{gjId}")]
        public IActionResult Inject(int gjId, [FromQuery] bool isClone)
        {
            _gjService.InjectGeneralJournal(gjId, isClone);

            return Ok();
        }

        #endregion
    }
}
