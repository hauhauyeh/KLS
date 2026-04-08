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
    [Display(Name = "Vendor Payment Management", GroupName = "Vendor")]
    public class VendorPaymentsController : BaseController
    {
        #region --- Member(s) ---

        private readonly IVendorPaymentService _vendorPaymentService;

        #endregion

        #region --- Constructor(s) ---

        public VendorPaymentsController(IVendorPaymentService vendorPaymentService)
        {
            _vendorPaymentService = vendorPaymentService;
        }

        #endregion

        #region --- Method(s) ---

        [HttpGet]
        [DisplayName("List Vendor Payments")]
        [PermissionKey("Vendor.VendorPayment.List")]
        public IActionResult List([FromQuery] VendorPaymentReq vendorPaymentReq)
        {
            return Ok(_vendorPaymentService.GetPagedVendorPayments(vendorPaymentReq));
        }


        [HttpGet("{paymentId}")]
        public IActionResult GetById(int paymentId)
        {
            return Ok(_vendorPaymentService.GetById(paymentId));
        }


        [HttpPost("Save")]
        [DisplayName("Create/Update Vendor Payment")]
        [PermissionKey("Vendor.VendorPayment.Save")]
        public IActionResult Save([FromBody] VendorPayment vendorPayment)
        {
            return Ok(_vendorPaymentService.Save(vendorPayment));
        }


        [HttpDelete("{paymentId}")]
        [DisplayName("Delete Vendor Payment")]
        [PermissionKey("Vendor.VendorPayment.Delete")]
        public IActionResult Delete(int paymentId)
        {
            _vendorPaymentService.Delete(paymentId);
            return Ok();
        }


        [HttpPost("VoidCheck/{paymentId}")]
        [DisplayName("Void Check")]
        [PermissionKey("Vendor.VendorPayment.VoidCheck")]
        public IActionResult VoidCheck(int paymentId)
        {
            _vendorPaymentService.VoidCheck(paymentId);
            return Ok();
        }


        [HttpPost("UnVoidCheck/{paymentId}")]
        [DisplayName("UnVoid Check")]
        [PermissionKey("Vendor.VendorPayment.UnVoidCheck")]
        public IActionResult UnVoidCheck(int paymentId)
        {
            _vendorPaymentService.UnVoidCheck(paymentId);
            return Ok();
        }


        [HttpPost("Return")]
        [DisplayName("Create Return Vendor Payment")]
        [PermissionKey("Vendor.VendorPayment.Return")]
        public IActionResult Return([FromBody] VendorPaymentReturnReq checkReq)
        {
            _vendorPaymentService.Return(checkReq);
            return Ok();
        }


        [HttpDelete("DeleteReturn/{paymentId}")]
        [DisplayName("Delete Return Vendor Payment")]
        [PermissionKey("Vendor.VendorPayment.DeleteReturn")]
        public IActionResult DeleteReturn(int paymentId)
        {
            _vendorPaymentService.DeleteReturn(paymentId);
            return Ok();
        }


        [HttpGet("ReturnTypes")]
        public IActionResult ReturnTypes()
        {
            return Ok(_vendorPaymentService.GetReturnTypes());
        }


        [HttpPost("SavePayNow")]
        [DisplayName("Create/Update Pay NOW")]
        [PermissionKey("Vendor.VendorPayment.SavePayNow")]
        public IActionResult SavePayNow([FromBody] PayNowReq payNowReq)
        {
            return Ok(_vendorPaymentService.SavePayNow(payNowReq));
        }


        [HttpPost("ImportPayNow")]
        [DisplayName("Import Pay NOW")]
        [PermissionKey("Vendor.VendorPayment.ImportPayNow")]
        public IActionResult ImportPayNow([FromForm] ImportPayNow importPayNow)
        {
            var result = _vendorPaymentService.ImportPayNow(importPayNow);
            return Ok(result);
        }


        [HttpGet("GetAppliedBills")]
        public IActionResult GetAppliedBills(int vendorPaymentId)
        {
            return Ok(_vendorPaymentService.GetAppliedBills(vendorPaymentId));
        }


        [HttpGet("GetOpenAdvances/{payeeId}")]
        public IActionResult OpenAdvances(int payeeId)
        {
            return Ok(_vendorPaymentService.GetOpenAdvances(payeeId));
        }


        [HttpPost("ApplyAdvance")]
        [DisplayName("Apply Advance Payment")]
        [PermissionKey("Vendor.VendorPayment.ApplyAdvance")]
        public IActionResult ApplyAdvance([FromBody] AdvanceApplyReq req)
        {
            return Ok(_vendorPaymentService.ApplyAdvance(req));
        }


        [HttpPost("UnapplyAdvance/{paymentId}")]
        [DisplayName("Unapply Advance Payment")]
        [PermissionKey("Vendor.VendorPayment.UnapplyAdvance")]
        public IActionResult UnapplyAdvance(int paymentId)
        {
            return Ok(_vendorPaymentService.UnapplyAdvance(paymentId));
        }

        #endregion
    }
}
