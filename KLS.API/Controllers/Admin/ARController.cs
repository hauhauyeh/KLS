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
    [Display(Name = "AR Management", GroupName = "Customer")]
    public class ARController : BaseController
    {
        #region --- Member(s) ---

        private readonly IPayeeService _payeeService;
        private readonly ICustomerPaymentService _customerPaymentService;

        #endregion

        #region --- Constructor(s) ---

        public ARController(IPayeeService payeeService, ICustomerPaymentService customerPaymentService)
        {
            _payeeService = payeeService;
            _customerPaymentService = customerPaymentService;
        }

        #endregion

        #region --- Method(s) ---

        [HttpGet]
        [DisplayName("List AR")]
        [PermissionKey("Customer.AR.List")]
        public IActionResult List([FromQuery] ARCustomerListReq arListReq)
        {
            return Ok(_payeeService.GetARCustomers(arListReq));
        }


        [HttpPost("ChargePayment")]
        [DisplayName("Charge Payment")]
        [PermissionKey("Customer.AR.ChargePayment")]
        public IActionResult ChargePayment([FromBody] PaymentChargeReq chargeReq)
        {
            return Ok(_customerPaymentService.ChargePayment(chargeReq));
        }

        #endregion
    }
}
