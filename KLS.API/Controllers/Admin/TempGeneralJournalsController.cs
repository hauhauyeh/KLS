using KLS.API.Helpers;
using KLS.Models;
using KLS.Services.Interfaces;
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel.DataAnnotations;

namespace KLS.API.Controllers.Admin
{
    [AuthorizeAdmin]
    [Route("api/admin/[controller]")]
    [Display(Name = "Temp GeneralJournal Management", GroupName = "Admin")]
    public class TempGeneralJournalsController : BaseController
    {
        #region --- Member(s) ---

        private readonly ITempGeneralJournalService _tempGJService;
        private readonly IAccountService _accountService;

        #endregion

        #region --- Constructor(s) ---

        public TempGeneralJournalsController(ITempGeneralJournalService tempGJService, IAccountService accountService)
        {
            _tempGJService = tempGJService;
            _accountService = accountService;
        }

        #endregion

        #region --- Method(s) ---

        [HttpGet]
        public IActionResult GetTempGJList([FromQuery] TempGJReq tempGJReq)
        {
            return Ok(_tempGJService.GetTempGJList(tempGJReq));
        }


        [HttpPost]
        public IActionResult Create([FromBody] TempGeneralJournal tempGJ)
        {
            if (_accountService.CheckAccount(tempGJ.AccountId.ToString()?? "") == null)
                return Conflict("Account is not found");

            return Ok(_tempGJService.CreateTempGJ(tempGJ));
        }


        [HttpPut]
        public IActionResult Update([FromBody] TempGeneralJournal tempGJ)
        {
            return Ok(_tempGJService.UpdateTempGJ(tempGJ));
        }


        [HttpDelete("{id}")]
        public IActionResult Delete(int id)
        {
            _tempGJService.DeleteTempGJ(id);
            return Ok();
        }

        #endregion
    }
}
