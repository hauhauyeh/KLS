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
    [Display(Name = "Purchase Management", GroupName = "Vendor")]
    public class PurchasesController : BaseController
    {
        #region --- Member(s) ---

        private readonly IPurchaseService _purchaseService;
        private readonly IWebHostEnvironment _env;

        #endregion

        #region --- Constructor(s) ---

        public PurchasesController(IPurchaseService purchaseService, IWebHostEnvironment env)
        {
            _purchaseService = purchaseService;
            _env = env;
        }

        #endregion

        #region --- Method(s) ---

        [HttpGet]
        [DisplayName("Bill Manager")]
        public IActionResult List([FromQuery] PurchaseListReq purchaseListReq)
        {
            return Ok(_purchaseService.GetPagedList(purchaseListReq));
        }


        [HttpGet("{purchaseId}")]
        public IActionResult GetById(int purchaseId)
        {
            var purchase = _purchaseService.GetById(purchaseId);

            if (purchase == null)
                return NotFound($"Purchase with Id {purchaseId} not found.");

            return Ok(purchase);
        }


        [HttpPut("UpdateNotes")]
        public IActionResult UpdateNotes([FromBody] PurchaseUpdateReq updateReq)
        {
            _purchaseService.UpdateNotes(updateReq.PurchaseId, updateReq.Notes);

            return Ok();
        }


        [HttpPut("UpdateDocNumber")]
        public IActionResult UpdateDocNumber([FromBody] PurchaseUpdateReq updateReq)
        {
            _purchaseService.UpdateDocNumber(updateReq.PurchaseId, updateReq.VendorDocNumber);

            return Ok();
        }


        [HttpPut("UpdateInvoiceDate")]
        public IActionResult UpdateInvoiceDate([FromBody] PurchaseUpdateReq updateReq)
        {
            _purchaseService.UpdateInvoiceDate(updateReq.PurchaseId, updateReq.InvoiceDate);

            return Ok();
        }


        [HttpPut("UpdateCommission")]
        public IActionResult UpdateCommission([FromBody] PurchaseUpdateReq updateReq)
        {
            _purchaseService.UpdateCommission(updateReq.PurchaseId, updateReq.ImportCommission);

            return Ok();
        }


        [HttpPut("UpdatePallet")]
        public IActionResult UpdatePallet([FromBody] PurchaseUpdateReq updateReq)
        {
            _purchaseService.UpdatePallet(updateReq.PurchaseId, updateReq.PalletCount);

            return Ok();
        }


        [HttpPut("UpdateNameDate")]
        public IActionResult UpdateNameDate([FromBody] PurchaseUpdateReq updateReq)
        {
            return Ok(_purchaseService.UpdateNameDate(updateReq));
        }


        [HttpPut("UpdateContainer")]
        public IActionResult UpdateContainer([FromBody] PurchaseUpdateReq updateReq)
        {
            return Ok(_purchaseService.UpdateContainerNumber(updateReq.PurchaseId, updateReq.ContainerNumber));
        }


        [HttpPost("Checkout")]
        [DisplayName("Checkout Bill")]
        public IActionResult Checkout([FromBody] PurchaseCheckoutReq checkoutReq)
        {
            return Ok(_purchaseService.Checkout(checkoutReq));
        }


        [HttpPut("UpdatePartially/{purchaseId}")]
        public IActionResult UpdatePartially(int purchaseId)
        {
            return Ok(_purchaseService.UpdatePartially(purchaseId));
        }


        [HttpDelete("{purchaseId}")]
        [DisplayName("Delete Bill")]
        public IActionResult Delete(int purchaseId)
        {
            _purchaseService.Delete(purchaseId);

            return Ok();
        }


        [HttpPost("Inject")]
        public IActionResult Inject([FromBody] PurchaseInjectReq injectReq)
        {
            _purchaseService.Inject(injectReq);
            return Ok();
        }


        [HttpPost("UploadBillPDF")]
        public IActionResult UploadBillPDF([FromForm] PDFUploadReq pdfUploadReq)
        {
            _purchaseService.UploadBillPDF(pdfUploadReq);

            return Ok();
        }


        [HttpGet("SeePDF/{purchaseNumber}")]
        [DisplayName("See PDF Image")]
        public IActionResult SeePdf(int purchaseNumber)
        {
            var filePath = Path.Combine(_env.WebRootPath, "BillPdf", purchaseNumber + ".pdf");

            if (!System.IO.File.Exists(filePath))
                return NotFound("File not found.");

            var fileStream = new FileStream(filePath, FileMode.Open, FileAccess.Read);
            return File(fileStream, "application/pdf");
        }

        #endregion
    }
}
