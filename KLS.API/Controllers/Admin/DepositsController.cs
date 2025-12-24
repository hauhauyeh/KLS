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
    [Display(Name = "Deposit Management", GroupName = "Customer")]
    public class DepositsController : BaseController
    {
        #region --- Member(s) ---

        private readonly ITransferFundService _transferFundService;

        #endregion

        #region --- Constructor(s) ---

        public DepositsController(ITransferFundService transferFundService)
        {
            _transferFundService = transferFundService;
        }

        #endregion

        #region --- Method(s) ---

        [HttpGet]
        [DisplayName("List Deposit")]
        public IActionResult List([FromQuery] DepositReq depositReq)
        {
            return Ok(_transferFundService.GetPagedDeposits(depositReq));
        }


        [HttpGet("{tfId}")]
        public IActionResult GetById(int tfId)
        {
            return Ok(_transferFundService.GetById(tfId));
        }


        [HttpPost]
        [DisplayName("Save Deposit")]
        public IActionResult Save([FromBody] TransferFund transferFund)
        {
            return Ok(_transferFundService.SaveDeposit(transferFund));
        }


        [HttpDelete("{tfId}")]
        [DisplayName("Delete Deposit")]
        public IActionResult Delete(int tfId)
        {
            _transferFundService.DeleteTransferFund(tfId);

            return Ok();
        }


        [HttpPost("Inject/{tfId}")]
        public IActionResult Inject(int tfId)
        {
            return Ok(_transferFundService.InjectDeposit(tfId));
        }

        #endregion
    }
}
