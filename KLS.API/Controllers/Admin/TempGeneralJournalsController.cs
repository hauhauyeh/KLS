using KLS.Models;
using KLS.Services.Interfaces;
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel;
using System.ComponentModel.DataAnnotations;

namespace KLS.API.Controllers.Admin
{
    //[AuthorizeAdmin]
    [Route("api/admin/[controller]")]
    [Display(Name = "TempGeneralJournal Management", GroupName = "Admin")]
    public class TempGeneralJournalsController : BaseController
    {
        #region --- Member(s) ---

        private readonly ITempGeneralJournalService _tempGeneralJournalService;

        #endregion

        #region --- Constructor(s) ---

        public TempGeneralJournalsController(ITempGeneralJournalService tempGeneralJournalService)
        {
            _tempGeneralJournalService = tempGeneralJournalService;
        }

        #endregion

        #region --- Method(s) ---

        [HttpGet]
        public IActionResult GetAllTempGeneralJournal([FromQuery] TempGeneralJournalReq req)
        {
            return Ok(_tempGeneralJournalService.GetTempGeneralJournalDetails(req.GJId, req.EmployeeId, req.TempGJId));
        }


        [HttpPost]
        public IActionResult CreateTempGeneralJournal([FromBody] TempGeneralJournal tempGeneralJournal)
        {
            return Ok(_tempGeneralJournalService.CreateTempGeneralJournal(tempGeneralJournal));
        }


        [HttpPut]
        public IActionResult UpdateTempGeneralJournal([FromBody] TempGeneralJournal tempGeneralJournal)
        {
            return Ok(_tempGeneralJournalService.UpdateTempGeneralJournal(tempGeneralJournal));
        }


        [HttpDelete("{id}")]
        public IActionResult DeleteTempGeneralJournal(int id)
        {
            _tempGeneralJournalService.DeleteTempGeneralJournal(id);
            return Ok();
        }

        #endregion
    }
}
