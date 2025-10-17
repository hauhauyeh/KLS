using KLS.API.Helpers;
using KLS.Models;
using KLS.Services;
using KLS.Services.Interfaces;
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel;
using System.ComponentModel.DataAnnotations;

namespace KLS.API.Controllers.Admin
{
    //[AuthorizeAdmin]
    [Route("api/admin/[controller]")]
    [Display(Name = "IncomingPayment Management", GroupName = "Admin")]
    public class IncomingPaymentsController : BaseController
    {
        #region --- Member(s) ---

        private readonly IIncomingPaymentService _incomingPaymentService;

        #endregion

        #region --- Constructor(s) ---

        public IncomingPaymentsController(IIncomingPaymentService incomingPaymentService)
        {
            _incomingPaymentService = incomingPaymentService;
        }

        #endregion

        #region --- Method(s) ---

        [HttpGet]
        [DisplayName("List IncomingPayment")]
        public IActionResult List([FromQuery] IncomingPaymentReq incomingPaymentReq)
        {
            return Ok(_incomingPaymentService.GetIncomingPayment(incomingPaymentReq));
        }

        #endregion
    }
}
