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
    [Display(Name = "PO Management", GroupName = "Vendor")]
    public class PurchaseOrdersController : BaseController
    {
        #region --- Member(s) ---

        private readonly IPurchaseOrderService _purchaseOrderService;
        private readonly IVendorPaymentService _vendorPaymentService;
        private const string CreatePermission = "Vendor.PurchaseOrder.Create";
        private const string UpdatePermission = "Vendor.PurchaseOrder.Update";

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
        [PermissionKey("Vendor.PurchaseOrder.List")]
        public IActionResult List([FromQuery] POListReq purchaseOrderReq)
        {
            return Ok(_purchaseOrderService.GetPagedList(purchaseOrderReq));
        }


        [HttpPost("Checkout")]
        [DisplayName("Create/Update PO")]
        public IActionResult Checkout([FromBody] POCheckoutReq checkoutReq)
        {
            var requiredPermission = checkoutReq.PurchaseId > 0 ? UpdatePermission : CreatePermission;
            if (!HasPermission(requiredPermission))
                return Forbid();

            return Ok(_purchaseOrderService.Checkout(checkoutReq));
        }


        [HttpDelete("{purchaseId}")]
        [DisplayName("Delete PO")]
        [PermissionKey("Vendor.PurchaseOrder.Delete")]
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
        [PermissionKey("Vendor.PurchaseOrder.CopyToBill")]
        public IActionResult CopyToBill([FromBody] POCopyToBillReq copyToBillReq)
        {
            return Ok(_purchaseOrderService.CopyToBill(copyToBillReq));
        }


        [HttpGet("PrintPO/{purchaseId}")]
        [DisplayName("Print PO")]
        [PermissionKey("Vendor.PurchaseOrder.Print")]
        public IActionResult PrintPO(int purchaseId)
        {
            var poFilePath = _purchaseOrderService.PrintPO(purchaseId);

            if (!System.IO.File.Exists(poFilePath))
                return NotFound("File not found.");

            var fileStream = new FileStream(poFilePath, FileMode.Open, FileAccess.Read, FileShare.Read);
            return File(fileStream, "application/pdf");
        }


        [HttpPost("EmailPdf/{purchaseId}")]
        [DisplayName("Email PO")]
        [PermissionKey("Vendor.PurchaseOrder.EmailPdf")]
        public IActionResult EmailPdf(int purchaseId, [FromForm] List<IFormFile>? files)
        {
            return Ok(_purchaseOrderService.EmailPdf(purchaseId, files));
        }


        [HttpPut("UpdateToBillStage/{purchaseId}")]
        [DisplayName("Convert To Bill")]
        [PermissionKey("Vendor.PurchaseOrder.ConvertToBill")]
        public IActionResult UpdateToBillStage(int purchaseId, [FromBody] PurchaseOrderConvertToBillReq? req)
        {
            return Ok(_purchaseOrderService.UpdateToBillStage(purchaseId, req));
        }


        [HttpPost("SaveAdvance")]
        [DisplayName("Save Advance Payment")]
        [PermissionKey("Vendor.PurchaseOrder.SaveAdvance")]
        public IActionResult SaveAdvance([FromBody] VendorPaymentAdvanceReq advancePaymentReq)
        {
            _vendorPaymentService.SaveAdvance(advancePaymentReq);
            return Ok();
        }


        [HttpGet("GetAdvances")]
        [DisplayName("Advance Payments")]
        [PermissionKey("Vendor.PurchaseOrder.GetAdvances")]
        public IActionResult GetAdvances(int purchaseId)
        {
            return Ok(_vendorPaymentService.GetAdvances(purchaseId));
        }


        [HttpDelete("DeleteAdvance/{paymentId}")]
        [DisplayName("Delete Advance Payment")]
        [PermissionKey("Vendor.PurchaseOrder.DeleteAdvance")]
        public IActionResult DeleteAdvance(int paymentId)
        {
            _vendorPaymentService.Delete(paymentId);
            return Ok();
        }

        private bool HasPermission(string permissionKey)
        {
            if (IsCurrentUserAdmin())
                return true;

            return HttpContext.Items["PermissionKeys"] is HashSet<string> permissionKeys
                && permissionKeys.Contains(permissionKey);
        }

        #endregion
    }
}
