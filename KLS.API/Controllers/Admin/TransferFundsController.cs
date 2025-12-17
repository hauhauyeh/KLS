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
    [Display(Name = "Transfer Fund Management", GroupName = "Accounting")]
    public class TransferFundsController : BaseController
    {
        #region --- Member(s) ---

        private readonly ITransferFundService _transferFundService;

        #endregion

        #region --- Constructor(s) ---

        public TransferFundsController(ITransferFundService transferFundService)
        {
            _transferFundService = transferFundService;
        }

        #endregion

        #region --- Method(s) ---

        [HttpGet]
        [DisplayName("List Transfer Fund")]
        public IActionResult List([FromQuery] TFReq tFReq)
        {
            return Ok(_transferFundService.GetAllTransferFunds(tFReq));
        }


        [HttpGet("{id}")]
        public IActionResult GetById(int id)
        {
            var tf = _transferFundService.GetById(id);

            if (tf == null)
                return NotFound($"Transfer Fund not found.");

            return Ok(tf);
        }


        [HttpPost("Save")]
        [DisplayName("Add/Edit Transfer Fund")]
        public IActionResult Save([FromBody] TransferFund transferFund)
        {
            return Ok(_transferFundService.SaveTransferFund(transferFund));
        }


        [HttpDelete("{id}")]
        [DisplayName("Delete Transfer Fund")]
        public IActionResult Delete(int id)
        {
            _transferFundService.DeleteTransferFund(id);

            return Ok();
        }

        #endregion
    }
}
