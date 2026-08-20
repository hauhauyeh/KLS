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
        [DisplayName("List Deposits")]
        [PermissionKey("Customer.Deposit.List")]
        public IActionResult List([FromQuery] DepositReq depositReq)
        {
            return Ok(_transferFundService.GetPagedDeposits(depositReq));
        }

        [HttpGet("Export")]
        [DisplayName("Export Deposits")]
        [PermissionKey("Customer.Deposit.List")]
        public IActionResult Export([FromQuery] DepositReq depositReq)
        {
            var bytes = _transferFundService.ExportDeposits(depositReq);
            var fileName = $"deposits-{DateTime.Today:yyyy-MM-dd}.csv";

            return File(bytes, "text/csv; charset=utf-8", fileName);
        }

        [HttpGet("{tfId}")]
        public IActionResult GetById(int tfId)
        {
            return Ok(_transferFundService.GetById(tfId));
        }


        [HttpPost]
        [DisplayName("Create/Update Deposit")]
        [PermissionKey("Customer.Deposit.Save")]
        public IActionResult Save([FromBody] TransferFund transferFund)
        {
            return Ok(_transferFundService.SaveDeposit(transferFund));
        }


        [HttpDelete("{tfId}")]
        [DisplayName("Delete Deposit")]
        [PermissionKey("Customer.Deposit.Delete")]
        public IActionResult Delete(int tfId)
        {
            _transferFundService.DeleteTransferFund(tfId);

            return Ok();
        }


        [HttpPost("Inject")]
        public IActionResult Inject([FromBody] DepositInjectReq injectReq)
        {
            return Ok(_transferFundService.InjectDeposit(injectReq));
        }

        #endregion
    }
}
