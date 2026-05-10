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

        [HttpGet]
        public IActionResult List([FromQuery] TempPaymentReq tempPaymentReq)
        {
            return Ok(_tempCustomerPaymentService.GetList(tempPaymentReq));
        }


        [HttpPost("Inject")]
        public IActionResult Inject([FromBody] TempPaymentReq tempPaymentReq)
        {
            return Ok(_tempCustomerPaymentService.Inject(tempPaymentReq));
        }


        [HttpPost]
        public IActionResult Create([FromBody] TempPaymentReq tempPaymentReq)
        {
            return Ok(_tempCustomerPaymentService.Create(tempPaymentReq));
        }


        [HttpPut]
        public IActionResult Update([FromBody] TempCustomerPayment tempCustomerPayment)
        {
            return Ok(_tempCustomerPaymentService.Update(tempCustomerPayment));
        }


        [HttpPost("Clear")]
        public IActionResult Clear(int payeeId)
        {
            _tempCustomerPaymentService.Clear(payeeId);
            return Ok();
        }


        [HttpDelete("{tempId}")]
        public IActionResult Delete(int tempId)
        {
            _tempCustomerPaymentService.Delete(tempId);
            return Ok();
        }


        #endregion
    }
}
