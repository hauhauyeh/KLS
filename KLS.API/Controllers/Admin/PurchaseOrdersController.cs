using KLS.API.Helpers;
using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Models;
using KLS.Services;
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel;
using System.ComponentModel.DataAnnotations;

namespace KLS.API.Controllers.Admin
{
    [AuthorizeAdmin]
    [Route("api/admin/[controller]")]
    [Display(Name = "PO Management", GroupName = "Vendor")]
    public class PurchaseOrdersController : BaseController
    {
        #region --- Member(s) ---

        private readonly IPurchaseOrderService _purchaseOrderService;
        private readonly IVendorPaymentService _vendorPaymentService;

        #endregion

        #region --- Constructor(s) ---

        public PurchaseOrdersController(IPurchaseOrderService purchaseOrderService, IVendorPaymentService vendorPaymentService)
        {
            _purchaseOrderService = purchaseOrderService;
            _vendorPaymentService = vendorPaymentService;
        }

        #endregion

        #region --- Method(s) ---

        [HttpGet]
        [DisplayName("List PO")]
        public IActionResult List([FromQuery] POListReq purchaseOrderReq)
        {
            return Ok(_purchaseOrderService.GetPagedList(purchaseOrderReq));
        }


        [HttpPost("Checkout")]
        [DisplayName("Create/Update PO")]
        public IActionResult Checkout([FromBody] POCheckoutReq checkoutReq)
        {
            return Ok(_purchaseOrderService.Checkout(checkoutReq));
        }


        [HttpDelete("{purchaseId}")]
        [DisplayName("Delete PO")]
        public IActionResult Delete(int purchaseId)
        {
            _purchaseOrderService.Delete(purchaseId);

            return Ok();
        }


        [HttpGet("GetPODetail/{purchaseId}")]
        public IActionResult GetPODetail(int purchaseId)
        {
            return Ok(_purchaseOrderService.GetPODetail(purchaseId));
        }


        [HttpPost("CopyToBill")]
        [DisplayName("Receive Product")]
        public IActionResult CopyToBill([FromBody] POCopyToBillReq copyToBillReq)
        {
            return Ok(_purchaseOrderService.CopyToBill(copyToBillReq));
        }


        [HttpGet("PrintPO/{purchaseId}")]
        [DisplayName("Print PO")]
        public IActionResult PrintPO(int purchaseId)
        {
            var poFilePath = _purchaseOrderService.PrintPO(purchaseId);

            if (!System.IO.File.Exists(poFilePath))
                return NotFound("File not found.");

            var fileStream = new FileStream(poFilePath, FileMode.Open, FileAccess.Read, FileShare.Read);
            return File(fileStream, "application/pdf");
        }


        [HttpPut("UpdateToBillStage/{purchaseId}")]
        [DisplayName("Convert To Bill")]
        public IActionResult UpdateToBillStage(int purchaseId)
        {
            return Ok(_purchaseOrderService.UpdateToBillStage(purchaseId));
        }


        [HttpPost("SaveAdvance")]
        [DisplayName("Save Advance Payment")]
        public IActionResult SaveAdvance([FromBody] VendorPaymentAdvanceReq advancePaymentReq)
        {
            _vendorPaymentService.SaveAdvance(advancePaymentReq);
            return Ok();
        }


        [HttpGet("GetAdvances")]
        [DisplayName("Advance Payments")]
        public IActionResult GetAdvances(int purchaseId)
        {
            return Ok(_vendorPaymentService.GetAdvances(purchaseId));
        }


        [HttpDelete("DeleteAdvance/{paymentId}")]
        [DisplayName("Delete Advance Payment")]
        public IActionResult DeleteAdvance(int paymentId)
        {
            _vendorPaymentService.Delete(paymentId);
            return Ok();
        }

        #endregion
    }
}
