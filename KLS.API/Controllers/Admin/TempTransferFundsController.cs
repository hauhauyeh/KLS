using KLS.API.Helpers;
using KLS.Models;
using KLS.Services.Interfaces;
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel.DataAnnotations;

namespace KLS.API.Controllers.Admin
{
    [AuthorizeAdmin]
    [Route("api/admin/[controller]")]
    [Display(Name = "Temp Deposit Management", GroupName = "Customer")]
    public class TempTransferFundsController : BaseController
    {
        #region --- Member(s) ---

        private readonly ITempTransferFundService _tempTransferFundService;

        #endregion

        #region --- Constructor(s) ---

        public TempTransferFundsController(ITempTransferFundService tempTransferFundService)
        {
            _tempTransferFundService = tempTransferFundService;
        }

        #endregion

        #region --- Method(s) ---

        [HttpPut]
        public IActionResult Update([FromBody] TempTransferFund tempTransfer)
        {
            _tempTransferFundService.Update(tempTransfer);

            return Ok();
        }


        [HttpPost("AppliedAll/{tfId}")]
        public IActionResult AppliedAll(int tfId)
        {
            _tempTransferFundService.AppliedAll(tfId);

            return Ok();
        }

        #endregion
    }
}
