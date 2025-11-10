using KLS.API.Helpers;
using KLS.Models;
using KLS.Services;
using KLS.Services.Interfaces;
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel.DataAnnotations;

namespace KLS.API.Controllers.Admin
{
    //[AuthorizeAdmin]
    [Route("api/admin/[controller]")]
    [Display(Name = "TempVendorPayment Management", GroupName = "Admin")]
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

        [HttpGet("{id}")]
        public IActionResult GetById(int id)
        {
            return Ok(_tempVendorPaymentService.GetById(id));
        }


        [HttpPost("Inject")]
        public IActionResult Inject(TempVendorPaymentListReq tempVendorPaymentListReq)
        {
            _tempVendorPaymentService.InjectTempVendorPayment(tempVendorPaymentListReq);

            return Ok();
        }


        [HttpPost("Update")]
        public IActionResult Update([FromBody] TempVendorPayment tempVendorPayment)
        {
            _tempVendorPaymentService.UpdateTempVendorPayment(tempVendorPayment);
            return Ok();
        }

        #endregion
    }
}
