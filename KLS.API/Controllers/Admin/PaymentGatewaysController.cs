using KLS.API.Helpers;
using KLS.Contract.Services;
using KLS.Services;
using Microsoft.AspNetCore.Mvc;

namespace KLS.API.Controllers.Admin
{
    [AuthorizeAdmin]
    [Route("api/admin/[controller]")]
    public class PaymentGatewaysController : BaseController
    {
        #region --- Member(s) ---

        private readonly IPaymentGatewayService _paymentGatewayService;

        #endregion

        #region --- Constructor(s) ---

        public PaymentGatewaysController(IPaymentGatewayService paymentGatewayService)
        {
            _paymentGatewayService = paymentGatewayService;
        }

        #endregion

        #region --- Method(s) ---

        [HttpGet]
        public IActionResult GetSQInfo()
        {
            return Ok(_paymentGatewayService.GetSQInfo());
        }

        #endregion
    }
}
