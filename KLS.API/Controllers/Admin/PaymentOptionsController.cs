using KLS.API.Helpers;
using KLS.Services.Interfaces;
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel;
using System.ComponentModel.DataAnnotations;

namespace KLS.API.Controllers.Admin
{
    [AuthorizeAdmin]
    [Route("api/admin/[controller]")]
    [Display(Name = "PaymentOption Management", GroupName = "Admin")]
    public class PaymentOptionsController : BaseController
    {
        #region --- Member(s) ---

        private readonly IPaymentOptionService _paymentOptionService;

        #endregion

        #region --- Constructor(s) ---

        public PaymentOptionsController(IPaymentOptionService paymentOptionService)
        {
            _paymentOptionService = paymentOptionService;
        }

        #endregion

        #region --- Method(s) ---

        [HttpGet]
        [DisplayName("List PaymentOption")]
        public IActionResult List()
        {
            return Ok(_paymentOptionService.GetAllPaymentOption());
        }

        #endregion
    }
}
