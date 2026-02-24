using KLS.API.Helpers;
using KLS.Contract.Services;
using KLS.Models;
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel;
using System.ComponentModel.DataAnnotations;

namespace KLS.API.Controllers.Admin
{
    [AuthorizeAdmin]
    [Route("api/admin/[controller]")]
    [Display(Name = "Payment Method Management", GroupName = "Customer")]
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

        [HttpGet("{payeeId}")]
        public IActionResult GetByPayeeId(int PayeeId)
        {
            return Ok(_paymentMethodService.GetByPayeeId(PayeeId));
        }


        [HttpPost]
        [DisplayName("Create Method")]
        public IActionResult Create([FromBody] PaymentMethod method)
        {
            if (_paymentMethodService.Exists(method))
                return Conflict("Payment method already exists");

            _paymentMethodService.Create(method);
            return Ok();
        }


        [HttpDelete("{paymentmethodId}")]
        [DisplayName("Delete Method")]
        public IActionResult Delete(int paymentmethodId)
        {
            _paymentMethodService.Delete(paymentmethodId);
            return Ok();
        }


        [HttpPut("{paymentmethodId}")]
        public IActionResult SetPrimary(int paymentmethodId)
        {
            _paymentMethodService.SetPrimary(paymentmethodId);
            return Ok();
        }

        #endregion
    }
}
