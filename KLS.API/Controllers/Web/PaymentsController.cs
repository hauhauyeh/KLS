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
        private readonly IPaymentGatewayService _paymentGatewayService;
        private readonly IStripeService _stripeService;
        private readonly IPaymentMethodService _paymentMethodService;

        #endregion

        #region --- Constructor(s) ---

        public PaymentsController(
            ICustomerPaymentService customerPaymentService,
            IPaymentGatewayService paymentGatewayService,
            IStripeService stripeService,
            IPaymentMethodService paymentMethodService)
        {
            _customerPaymentService = customerPaymentService;
            _paymentGatewayService = paymentGatewayService;
            _stripeService = stripeService;
            _paymentMethodService = paymentMethodService;
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

            if (string.IsNullOrEmpty(chargeReq.Gateway))
                chargeReq.Gateway = "MX";

            chargeReq.CCFeePercent ??= 0.01m;

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

        [HttpGet("StripeInfo")]
        public IActionResult GetStripeInfo()
        {
            return Ok(_paymentGatewayService.GetStripeInfo());
        }

        [HttpGet("ActiveGateways")]
        public IActionResult GetActiveGateways()
        {
            return Ok(_paymentGatewayService.GetActiveGateways());
        }

        [HttpPost("SaveStripeCard")]
        public async Task<IActionResult> SaveStripeCard([FromBody] SaveCardReq req)
        {
            var result = await _stripeService.SavePaymentMethod(UserContext.EmpId, req.PaymentMethodToken);
            var pm = _paymentMethodService.CreateStripeCard(UserContext.EmpId, result);
            return Ok(new { pm.PaymentMethodId, result.CardBrand, result.Last4 });
        }

        [HttpGet("SavedMethods")]
        public IActionResult GetSavedMethods()
        {
            return Ok(_paymentMethodService.GetSavedMethodsForWeb(UserContext.EmpId));
        }

        #endregion
    }
}
