using KLS.API.Helpers;
using KLS.Models;
using KLS.Services.Interfaces;
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
        [DisplayName("List Vendor Payment")]
        public IActionResult List([FromQuery] VendorPaymentReq vendorPaymentReq)
        {
            return Ok(_vendorPaymentService.GetAllVendorPayments(vendorPaymentReq));
        }


        [HttpGet("{paymentId}")]
        public IActionResult GetById(int paymentId)
        {
            return Ok(_vendorPaymentService.GetById(paymentId));
        }


        [HttpDelete("{paymentId}")]
        [DisplayName("Delete Payment")]
        public IActionResult Delete(int paymentId)
        {
            _vendorPaymentService.DeleteVendorPayment(paymentId);
            return Ok();
        }


        [HttpPost("VoidCheck/{paymentId}")]
        [DisplayName("Void Check")]
        public IActionResult VoidCheck(int paymentId)
        {
            _vendorPaymentService.VoidCheck(paymentId);
            return Ok();
        }


        [HttpPost("UnVoidCheck/{paymentId}")]
        [DisplayName("UnVoid Check")]
        public IActionResult UnVoidCheck(int paymentId)
        {
            _vendorPaymentService.UnVoidCheck(paymentId);
            return Ok();
        }


        [HttpPost("Return")]
        [DisplayName("Return Payment")]
        public IActionResult Return([FromBody] VendorPaymentReturnReq checkReq)
        {
            _vendorPaymentService.VendorPaymentReturn(checkReq);
            return Ok();
        }


        [HttpGet("ReturnTypes")]
        public IActionResult ReturnTypes()
        {
            return Ok(_vendorPaymentService.GetReturnTypes());
        }

        #endregion
    }
}
