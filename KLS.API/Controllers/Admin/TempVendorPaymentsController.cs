using KLS.API.Helpers;
using KLS.Contract.Services;
using KLS.Models;
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel.DataAnnotations;

namespace KLS.API.Controllers.Admin
{
    [AuthorizeAdmin]
    [Route("api/admin/[controller]")]
    [Display(Name = "Temp VendorPayment Management", GroupName = "Vendor")]
    public class TempVendorPaymentsController : BaseController
    {
        #region --- Member(s) ---

        private readonly ITempVendorPaymentService _tempVendorPaymentService;

        #endregion

        #region --- Constructor(s) ---

        public TempVendorPaymentsController(ITempVendorPaymentService tempVendorPaymentService)
        {
            _tempVendorPaymentService = tempVendorPaymentService;
        }

        #endregion

        #region --- Method(s) ---

        [HttpPost("Inject")]
        public IActionResult Inject(TempPaymentReq tempPaymentReq)
        {
            return Ok(_tempVendorPaymentService.Inject(tempPaymentReq));
        }


        [HttpPut]
        public IActionResult Update([FromBody] TempVendorPayment tempVendorPayment)
        {
            _tempVendorPaymentService.Update(tempVendorPayment);
            return Ok();
        }

        #endregion
    }
}
