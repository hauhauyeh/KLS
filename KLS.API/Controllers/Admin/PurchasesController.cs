using KLS.API.Helpers;
using KLS.Models;
using KLS.Services;
using KLS.Services.Interfaces;
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel;
using System.ComponentModel.DataAnnotations;

namespace KLS.API.Controllers.Admin
{
    [AuthorizeAdmin]
    [Route("api/admin/[controller]")]
    [Display(Name = "Purchase Management", GroupName = "Admin")]
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
            return Ok(_purchaseService.GetAllPurchase(purchaseListReq));
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


        [HttpDelete("{purchaseId}")]
        [DisplayName("Delete Bill")]
        public IActionResult Delete(int purchaseId)
        {
            _purchaseService.DeletePurchase(purchaseId);

            return Ok();
        }


        [HttpPost("UploadBillPDF")]
        public IActionResult UploadBillPDF([FromForm] PDFUploadReq pdfUploadReq)
        {
            _purchaseService.UploadBillPDF(pdfUploadReq);

            return Ok();
        }


        [HttpPost("Inject")]
        public IActionResult Inject([FromBody] PurchaseInjectReq injectReq)
        {
            _purchaseService.InjectPurchase(injectReq);
            return Ok();
        }


        [HttpPost("Checkout")]
        [DisplayName("Checkout Bill")]
        public IActionResult Checkout([FromBody] PurchaseCheckoutReq checkoutReq)
        {
            return Ok(_purchaseService.Checkout(checkoutReq));
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
