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
    [Display(Name = "VendorPmt Management", GroupName = "Vendor")]
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
        [DisplayName("List VendorPayments")]
        public IActionResult List([FromQuery] VendorPaymentReq vendorPaymentReq)
        {
            return Ok(_vendorPaymentService.GetVendorPayment(vendorPaymentReq));
        }


        [HttpPost("ReturnCheck")]
        public IActionResult VendorPaymentReturnCheck([FromBody] VendorPaymentReturnReq checkReq)
        {
            _vendorPaymentService.VendorPaymentReturnCheck(checkReq);
            return Ok();
        }

        #endregion
    }
}
