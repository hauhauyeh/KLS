using KLS.API.Helpers;
using KLS.Models;
using KLS.Services;
using KLS.Services.Interfaces;
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel;
using System.ComponentModel.DataAnnotations;

namespace KLS.API.Controllers.Admin
{
    //[AuthorizeAdmin]
    [Route("api/admin/[controller]")]
    [Display(Name = "GeneralJournal Management", GroupName = "Admin")]
    public class GeneralJournalsController : BaseController
    {
        #region --- Member(s) ---

        private readonly IGeneralJournalService _generalJournalService;

        #endregion

        #region --- Constructor(s) ---

        public GeneralJournalsController(IGeneralJournalService generalJournalService)
        {
            _generalJournalService = generalJournalService;
        }

        #endregion

        #region --- Method(s) ---

        [HttpGet]
        [DisplayName("List GeneralJournal")]
        public IActionResult GetAll([FromQuery] GeneralJournalReq generalJournalReq)
        {
            return Ok(_generalJournalService.GetAllGeneralJournal(generalJournalReq));
        }

        #endregion
    }
}
