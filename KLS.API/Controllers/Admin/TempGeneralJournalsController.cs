using KLS.API.Helpers;
using KLS.Contract.Services;
using KLS.Models;
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
        public IActionResult List([FromQuery] TempGJReq tempGJReq)
        {
            return Ok(_tempGJService.GetList(tempGJReq));
        }


        [HttpPost]
        public IActionResult Create([FromBody] TempGeneralJournal tempGJ)
        {
            if (_accountService.CheckAccount(tempGJ.AccountId.ToString()?? "") == null)
                return Conflict("Account is not found");

            return Ok(_tempGJService.Create(tempGJ));
        }


        [HttpPut]
        public IActionResult Update([FromBody] TempGeneralJournal tempGJ)
        {
            return Ok(_tempGJService.Update(tempGJ));
        }


        [HttpDelete("{id}")]
        public IActionResult Delete(int id)
        {
            _tempGJService.Delete(id);
            return Ok();
        }

        #endregion
    }
}
