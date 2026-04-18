using KLS.API.Helpers;
using KLS.Common;
using KLS.Contract.Services;
using KLS.Models;
using Microsoft.AspNetCore.Mvc;

namespace KLS.API.Controllers.Web
{
    [AuthorizeWeb]
    [Route("api/web/[controller]")]
    public class PaymentMethodsController : BaseController
    {
        #region --- Member(s) ---

        private readonly IPaymentMethodService _paymentMethodService;

        #endregion

        #region --- Constructor(s) ---

        public PaymentMethodsController(IPaymentMethodService paymentMethodService)
        {
            _paymentMethodService = paymentMethodService;
        }

        #endregion

        #region --- Method(s) ---

        [HttpGet]
        public IActionResult GetByPayeeId()
        {
            return Ok(_paymentMethodService.GetByPayeeId(UserContext.EmpId));
        }


        [HttpPost]
        public IActionResult Create([FromBody] PaymentMethod method)
        {
            method.PayeeId = UserContext.EmpId;

            if (_paymentMethodService.Exists(method))
                return Conflict("Payment method already exists");

            _paymentMethodService.Create(method);
            return Ok();
        }


        [HttpDelete("{paymentMethodId}")]
        public IActionResult Delete(int paymentMethodId)
        {
            _paymentMethodService.Delete(paymentMethodId);
            return Ok();
        }


        [HttpPut("{paymentMethodId}")]
        public IActionResult SetPrimary(int paymentMethodId)
        {
            _paymentMethodService.SetPrimary(paymentMethodId);
            return Ok();
        }

        #endregion
    }
}
