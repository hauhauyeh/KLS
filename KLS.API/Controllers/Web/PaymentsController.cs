using KLS.API.Helpers;
using KLS.Common;
using KLS.Contract.Services;
using KLS.Models;
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel.DataAnnotations;

namespace KLS.API.Controllers.Web
{
    [AuthorizeWeb]
    [Route("api/web/[controller]")]
    [Display(Name = "Payments", GroupName = "Web")]
    public class PaymentsController : BaseController
    {
        #region --- Member(s) ---

        private readonly ICustomerPaymentService _customerPaymentService;
        private readonly IPaymentMethodService _paymentMethodService;

        #endregion

        #region --- Constructor(s) ---

        public PaymentsController(ICustomerPaymentService customerPaymentService, IPaymentMethodService paymentMethodService)
        {
            _customerPaymentService = customerPaymentService;
            _paymentMethodService = paymentMethodService;
        }

        #endregion

        #region --- Method(s) ---

        [HttpGet("Methods")]
        public IActionResult GetMethods()
        {
            return Ok(_paymentMethodService.GetByPayeeId(UserContext.EmpId));
        }


        [HttpGet("Total")]
        public IActionResult GetTotal([FromQuery] string salesIds)
        {
            return Ok(_customerPaymentService.GetDueTotal(salesIds));
        }


        [HttpPost("Charge")]
        public IActionResult ChargePayment([FromBody] PaymentChargeReq chargeReq)
        {
            chargeReq.PayeeId = UserContext.EmpId;

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
