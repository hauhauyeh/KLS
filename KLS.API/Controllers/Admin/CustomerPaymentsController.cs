using KLS.API.Helpers;
using KLS.Models;
using KLS.Services.Interfaces;
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel;
using System.ComponentModel.DataAnnotations;

namespace KLS.API.Controllers.Admin
{
    [AuthorizeAdmin]
    [Route("api/admin/[controller]")]
    [Display(Name = "Customer Payment Management", GroupName = "Customer")]
    public class CustomerPaymentsController : BaseController
    {
        #region --- Member(s) ---

        private readonly ICustomerPaymentService _customerPaymentService;

        #endregion

        #region --- Constructor(s) ---

        public CustomerPaymentsController(ICustomerPaymentService customerPaymentService)
        {
            _customerPaymentService = customerPaymentService;
        }

        #endregion

        #region --- Method(s) ---

        [HttpGet]
        [DisplayName("List CustomerPayment")]
        public IActionResult List([FromQuery] CustomerPaymentReq customerPaymentReq)
        {
            return Ok(_customerPaymentService.GetCustomerPayment(customerPaymentReq));
        }

        #endregion
    }
}
