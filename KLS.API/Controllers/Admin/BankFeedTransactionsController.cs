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
    [Display(Name = "Bank Feed Transaction Management", GroupName = "Accounting")]
    public class BankFeedTransactionsController : BaseController
    {
        #region --- Member(s) ---

        private readonly IBankFeedTransactionService _bankFeedTransactionService;

        #endregion

        #region --- Constructor(s) ---

        public BankFeedTransactionsController(IBankFeedTransactionService bankFeedTransactionService)
        {
            _bankFeedTransactionService = bankFeedTransactionService;
        }

        #endregion

        #region --- Method(s) ---

        [HttpPost("UploadPreview")]
        [DisplayName("Upload Preview")]
        [PermissionKey("Accounting.BankFeed.Import")]
        public IActionResult UploadPreview([FromForm] BankFeedUploadPreviewReq req)
        {
            return Ok(_bankFeedTransactionService.UploadPreview(req));
        }

        [HttpPost("Import")]
        [DisplayName("Import Bank Feed")]
        [PermissionKey("Accounting.BankFeed.Import")]
        public IActionResult Import([FromBody] BankFeedImportReq req)
        {
            return Ok(_bankFeedTransactionService.Import(req));
        }

        [HttpGet]
        [DisplayName("List Bank Feed Transactions")]
        [PermissionKey("Accounting.BankFeed.List")]
        public IActionResult List([FromQuery] BankFeedListReq req)
        {
            return Ok(_bankFeedTransactionService.GetList(req));
        }

        [HttpGet("MatchCandidates/{id}")]
        [DisplayName("Bank Feed Match Candidates")]
        [PermissionKey("Accounting.BankFeed.Match")]
        public IActionResult MatchCandidates(long id)
        {
            return Ok(_bankFeedTransactionService.GetMatchCandidates(id));
        }

        [HttpGet("OpenBills")]
        [DisplayName("Bank Feed Open Bills")]
        [PermissionKey("Accounting.BankFeed.Match")]
        public IActionResult OpenBills([FromQuery] BankFeedOpenBillsReq req)
        {
            return Ok(_bankFeedTransactionService.GetOpenBills(req));
        }

        [HttpGet("UndepositedPayments")]
        [DisplayName("Bank Feed Undeposited Payments")]
        [PermissionKey("Accounting.BankFeed.Match")]
        public IActionResult UndepositedPayments([FromQuery] BankFeedUndepositedPaymentsReq req)
        {
            return Ok(_bankFeedTransactionService.GetUndepositedPayments(req));
        }

        [HttpPost("CreateVendorPayment")]
        [DisplayName("Create Vendor Payment From Bank Feed")]
        [PermissionKey("Accounting.BankFeed.Match")]
        public IActionResult CreateVendorPayment([FromBody] BankFeedCreateVendorPaymentReq req)
        {
            return Ok(_bankFeedTransactionService.CreateVendorPayment(req));
        }

        [HttpGet("OpenInvoices")]
        [DisplayName("Bank Feed Open Invoices")]
        [PermissionKey("Accounting.BankFeed.Match")]
        public IActionResult OpenInvoices([FromQuery] BankFeedOpenInvoicesReq req)
        {
            return Ok(_bankFeedTransactionService.GetOpenInvoices(req));
        }

        [HttpPost("CreateDeposit")]
        [DisplayName("Create Deposit From Bank Feed")]
        [PermissionKey("Accounting.BankFeed.Match")]
        public IActionResult CreateDeposit([FromBody] BankFeedCreateDepositReq req)
        {
            return Ok(_bankFeedTransactionService.CreateDeposit(req));
        }

        [HttpPost("CreateInvoiceDeposit")]
        [DisplayName("Receive Open Invoices From Bank Feed")]
        [PermissionKey("Accounting.BankFeed.Match")]
        public IActionResult CreateInvoiceDeposit([FromBody] BankFeedCreateInvoiceDepositReq req)
        {
            return Ok(_bankFeedTransactionService.CreateInvoiceDeposit(req));
        }

        /// <summary>Payee used on the most recent bank charge, so the picker opens pre-filled.</summary>
        [HttpGet("LastChargePayee")]
        [PermissionKey("Accounting.BankFeed.Match")]
        public IActionResult LastChargePayee()
        {
            return Ok(_bankFeedTransactionService.GetLastChargePayee());
        }

        [HttpPost("ReverseGenerated")]
        [DisplayName("Reverse Bank Feed Generated Transactions")]
        [PermissionKey("Accounting.BankFeed.Match")]
        public IActionResult ReverseGenerated([FromBody] BankFeedReverseReq req)
        {
            _bankFeedTransactionService.ReverseGenerated(req);
            return Ok();
        }

        [HttpPost("Match")]
        [DisplayName("Match Bank Feed")]
        [PermissionKey("Accounting.BankFeed.Match")]
        public IActionResult Match([FromBody] List<BankFeedMatchReq> reqs)
        {
            _bankFeedTransactionService.Match(reqs);
            return Ok();
        }

        [HttpPost("Unmatch")]
        [DisplayName("Unmatch Bank Feed")]
        [PermissionKey("Accounting.BankFeed.Match")]
        public IActionResult Unmatch([FromBody] BankFeedBulkActionReq req)
        {
            return Ok(_bankFeedTransactionService.Unmatch(req));
        }

        [HttpPost("Exclude")]
        [DisplayName("Exclude Bank Feed Transaction")]
        [PermissionKey("Accounting.BankFeed.Exclude")]
        public IActionResult Exclude([FromBody] BankFeedBulkExcludeReq req)
        {
            return Ok(_bankFeedTransactionService.Exclude(req));
        }

        [HttpPost("UnExclude")]
        [DisplayName("Un-Exclude Bank Feed Transaction")]
        [PermissionKey("Accounting.BankFeed.Exclude")]
        public IActionResult UnExclude([FromBody] BankFeedBulkActionReq req)
        {
            return Ok(_bankFeedTransactionService.UnExclude(req));
        }

        [HttpPost("Delete")]
        [DisplayName("Delete Bank Feed Transaction")]
        [PermissionKey("Accounting.BankFeed.Delete")]
        public IActionResult Delete([FromBody] BankFeedBulkActionReq req)
        {
            return Ok(_bankFeedTransactionService.Delete(req));
        }

        #endregion
    }
}
