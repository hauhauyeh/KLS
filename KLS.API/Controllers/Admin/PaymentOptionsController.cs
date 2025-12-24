using KLS.API.Helpers;
using KLS.Contract.Services;
using Microsoft.AspNetCore.Mvc;


namespace KLS.API.Controllers.Admin
{
    [AuthorizeAdmin]
    [Route("api/admin/[controller]")]
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
        public IActionResult List()
        {
            return Ok(_paymentOptionService.GetList());
        }

        #endregion
    }
}
