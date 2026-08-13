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
    [Display(Name = "Bill Management", GroupName = "Vendor")]
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
        [DisplayName("List Bills")]
        [PermissionKey("Vendor.Purchase.List")]
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


        [HttpGet("Detail/{purchaseId}")]
        public IActionResult Detail(int purchaseId)
        {
            return Ok(_purchaseService.GetPurchaseDetails(purchaseId));
        }


        [HttpPut("UpdateNotes")]
        public IActionResult UpdateNotes([FromBody] PurchaseUpdateReq updateReq)
        {
            _purchaseService.UpdateNotes(updateReq.PurchaseId, updateReq.Notes);

            return Ok();
        }


        [HttpPut("UpdateDocNumber")]
        [DisplayName("Update Doc Number")]
        [PermissionKey("Vendor.Purchase.UpdateDocNumber")]
        public IActionResult UpdateDocNumber([FromBody] PurchaseUpdateReq updateReq)
        {
            if (_purchaseService.DocNumberExists(updateReq.PurchaseId, updateReq.PayeeId ?? 0, updateReq.VendorDocNumber))
                return Conflict("Doc# already exists");

            return Ok(_purchaseService.UpdateDocNumber(updateReq.PurchaseId, updateReq.VendorDocNumber));
        }


        [HttpPut("UpdateInvoiceDate")]
        [DisplayName("Update Invoice Date")]
        [PermissionKey("Vendor.Purchase.UpdateInvoiceDate")]
        public IActionResult UpdateInvoiceDate([FromBody] PurchaseUpdateReq updateReq)
        {
            _purchaseService.UpdateInvoiceDate(updateReq.PurchaseId, updateReq.InvoiceDate);

            return Ok();
        }


        [HttpPut("UpdateCommission")]
        [DisplayName("Update Commission")]
        [PermissionKey("Vendor.Purchase.UpdateCommission")]
        public IActionResult UpdateCommission([FromBody] PurchaseUpdateReq updateReq)
        {
            _purchaseService.UpdateCommission(updateReq.PurchaseId, updateReq.ImportCommission);

            return Ok();
        }


        [HttpPut("UpdatePallet")]
        [DisplayName("Update Pallet")]
        [PermissionKey("Vendor.Purchase.UpdatePallet")]
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
        [DisplayName("Update Container")]
        [PermissionKey("Vendor.Purchase.UpdateContainer")]
        public IActionResult UpdateContainer([FromBody] PurchaseUpdateReq updateReq)
        {
            return Ok(_purchaseService.UpdateContainerNumber(updateReq.PurchaseId, updateReq.ContainerNumber));
        }


        [HttpPut("UpdateFactorPO")]
        [DisplayName("Update Factor PO")]
        [PermissionKey("Vendor.Purchase.Update")]
        public IActionResult UpdateFactorPO([FromBody] PurchaseUpdateReq updateReq)
        {
            return Ok(_purchaseService.UpdateFactorPO(updateReq.PurchaseId, updateReq.FactorPO));
        }


        [HttpPost("Checkout")]
        [DisplayName("Create Bill")]
        [PermissionKey("Vendor.Purchase.Create")]
        public IActionResult Checkout([FromBody] PurchaseCheckoutReq checkoutReq)
        {
            return Ok(_purchaseService.Checkout(checkoutReq));
        }


        [HttpPut("UpdatePartially/{purchaseId}")]
        [DisplayName("Update Bill")]
        [PermissionKey("Vendor.Purchase.Update")]
        public IActionResult UpdatePartially(int purchaseId)
        {
            return Ok(_purchaseService.UpdatePartially(purchaseId));
        }


        [HttpDelete("{purchaseId}")]
        [DisplayName("Delete Bill")]
        [PermissionKey("Vendor.Purchase.Delete")]
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
        [DisplayName("Upload Bill Pdf")]
        [PermissionKey("Vendor.Purchase.UploadBillPDF")]
        public IActionResult UploadBillPDF([FromForm] PDFUploadReq pdfUploadReq)
        {
            _purchaseService.UploadBillPDF(pdfUploadReq);

            return Ok();
        }


        [HttpGet("SeePDF/{purchaseNumber}")]
        [DisplayName("See PDF Image")]
        [PermissionKey("Vendor.Purchase.SeePdf")]
        public IActionResult SeePdf(int purchaseNumber)
        {
            var filePath = Path.Combine(_env.WebRootPath, "BillPdf", purchaseNumber + ".pdf");

            if (!System.IO.File.Exists(filePath))
                return NotFound("File not found.");

            var fileStream = new FileStream(filePath, FileMode.Open, FileAccess.Read);
            return File(fileStream, "application/pdf");
        }


        [HttpGet("SeePayment/{purchaseId}")]
        [DisplayName("See Payment")]
        public IActionResult SeePayment(int purchaseId)
        {
            return Ok(_purchaseService.SeePayment(purchaseId));
        }


        [HttpGet("AssignedShipments/{purchaseId}")]
        public IActionResult AssignedShipments(int purchaseId)
        {
            return Ok(_purchaseService.AssignedShipments(purchaseId, false));
        }


        [HttpPost("AssignShipment")]
        [DisplayName("Assign Shipment")]
        [PermissionKey("Vendor.Purchase.AssignShipment")]
        public IActionResult AssignShipment([FromBody] POCopyToBillReq copyToBillReq)
        {
            _purchaseService.AssignShipment(copyToBillReq);

            return Ok();
        }


        [HttpGet("OpenBills/{payeeId}")]
        public IActionResult OpenBills(int payeeId)
        {
            return Ok(_purchaseService.GetOpenBills(payeeId));
        }

        // Vendor purchase history panel — feeds the side drawer in
        // po-add-edit and purchase-add-edit. No per-action [PermissionKey];
        // gated only by the class-level [AuthorizeAdmin]. Matches the
        // sales-side precedent at SalesController.CustBoughtItemsPanel.
        [HttpGet("VendorPurchaseHistoryPanel/{payeeId}")]
        public IActionResult VendorPurchaseHistoryPanel(int payeeId)
        {
            return Ok(_purchaseService.VendorPurchaseHistoryPanel(payeeId));
        }


        [HttpPost("DocNumberExists")]
        public IActionResult DocNumberExists([FromBody] VendorDocCheckReq checkReq)
        {
            return Ok(_purchaseService.DocNumberExists(0, checkReq.PayeeId, checkReq.VendorDocNumber));
        }

        #endregion
    }
}
