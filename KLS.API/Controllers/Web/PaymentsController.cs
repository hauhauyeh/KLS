using KLS.API.Helpers;
using KLS.Common;
using KLS.Contract.Services;
using KLS.Models;
using Microsoft.AspNetCore.Mvc;

namespace KLS.API.Controllers.Web
{
    [AuthorizeWeb]
    [Route("api/web/[controller]")]
    public class PaymentsController : BaseController
    {
        #region --- Member(s) ---

        private readonly ICustomerPaymentService _customerPaymentService;

        #endregion

        #region --- Constructor(s) ---

        public PaymentsController(ICustomerPaymentService customerPaymentService)
        {
            _customerPaymentService = customerPaymentService;
        }

        #endregion

        #region --- Method(s) ---

        [HttpGet("Total")]
        public IActionResult GetTotal([FromQuery] string salesIds)
        {
            return Ok(_customerPaymentService.GetDueTotal(salesIds));
        }


        [HttpPost("Charge")]
        public IActionResult ChargePayment([FromBody] PaymentChargeReq chargeReq)
        {
            chargeReq.PayeeId = UserContext.EmpId;
            chargeReq.Gateway = "MX";
            chargeReq.CCFeePercent = 0.01m;

            var customerPayment = _customerPaymentService.ChargePayment(chargeReq);

            return Ok(customerPayment.CustomerPaymentId);
        }


        [HttpGet("{paymentId}")]
        public IActionResult GetDetails(int paymentId)
        {
            var payment = _customerPaymentService.GetDetails(paymentId);

            if (payment?.CustomerPayment?.PayeeId != UserContext.EmpId)
                return Forbid("You are not authorized to view this payment.");

            return Ok(payment);
        }

        #endregion
    }
}
