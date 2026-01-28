using KLS.API.Helpers;
using KLS.Contract.Services;
using KLS.Models;
using KLS.Services;
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel.DataAnnotations;

namespace KLS.API.Controllers.Admin
{
    [AuthorizeAdmin]
    [Route("api/admin/[controller]")]
    [Display(Name = "Temp CustomerPayment Management", GroupName = "Customer")]
    public class TempCustomerPaymentsController : BaseController
    {
        #region --- Member(s) ---

        private readonly ITempCustomerPaymentService _tempCustomerPaymentService;

        #endregion

        #region --- Constructor(s) ---

        public TempCustomerPaymentsController(ITempCustomerPaymentService tempCustomerPaymentService)
        {
            _tempCustomerPaymentService = tempCustomerPaymentService;
        }

        #endregion

        #region --- Method(s) ---

        [HttpPost("Inject")]
        public IActionResult Inject(TempPaymentReq tempPaymentReq)
        {
            return Ok(_tempCustomerPaymentService.Inject(tempPaymentReq));
        }


        [HttpPut]
        public IActionResult Update([FromBody] TempCustomerPayment tempCustomerPayment)
        {
            _tempCustomerPaymentService.Update(tempCustomerPayment);
            return Ok();
        }


        [HttpPost("Clear")]
        public IActionResult Clear([FromBody] TempPaymentReq tempPaymentReq)
        {
            _tempCustomerPaymentService.Clear(tempPaymentReq);
            return Ok();
        }

        #endregion
    }
}
