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
        [DisplayName("List Customer Payments")]
        public IActionResult List([FromQuery] CustomerPaymentReq customerPaymentReq)
        {
            return Ok(_customerPaymentService.GetPagedList(customerPaymentReq));
        }


        [HttpGet("{id}")]
        public IActionResult GetById(int id)
        {
            return Ok(_customerPaymentService.GetById(id));
        }


        [HttpDelete("{id}")]
        [DisplayName("Delete Payment")]
        public IActionResult Delete(int id)
        {
            _customerPaymentService.Delete(id);

            return Ok();
        }


        [HttpPut("UpdateNotes")]
        public IActionResult UpdateNotes([FromBody] CustomerPaymentUpdateReq updateReq)
        {
            _customerPaymentService.UpdateNotes(updateReq);

            return Ok();
        }


        [HttpPost]
        [DisplayName("Create/Update Customer Payment")]
        public IActionResult Save([FromBody] CustomerPaymentSaveReq paymentSaveReq)
        {
            return Ok(_customerPaymentService.Save(paymentSaveReq));
        }


        [HttpGet("ReturnTypes")]
        public IActionResult ReturnTypes()
        {
            return Ok(_customerPaymentService.GetReturnTypes());
        }


        [HttpPost("Return")]
        [DisplayName("Return Payment")]
        public IActionResult SaveReturn([FromBody] CustomerPaymentReturnReq returnReq)
        {
            _customerPaymentService.SaveReturn(returnReq);

            return Ok();
        }


        [HttpDelete("DeleteReturn/{id}")]
        [DisplayName("Delete Return Payment")]
        public IActionResult DeleteReturn(int id)
        {
            _customerPaymentService.DeleteReturn(id);

            return Ok();
        }


        [HttpGet("Statement/{payeeId}")]
        public IActionResult Statement(int payeeId)
        {
            return Ok(_customerPaymentService.Statement(payeeId));
        }


        #endregion
    }
}
