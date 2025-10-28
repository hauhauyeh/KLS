using KLS.API.Helpers;
using KLS.Models;
using KLS.Services;
using KLS.Services.Interfaces;
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel;
using System.ComponentModel.DataAnnotations;

namespace KLS.API.Controllers.Admin
{
    [AuthorizeAdmin]
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
        [DisplayName("List Incoming Payment")]
        public IActionResult List([FromQuery] IncomingPaymentListReq incomingPaymentReq)
        {
            return Ok(_incomingPaymentService.GetIncomingPayment(incomingPaymentReq));
        }


        [HttpGet("{id}")]
        public IActionResult GetById(int id)
        {
            var incomingPayment = _incomingPaymentService.GetById(id);

            if (incomingPayment == null)
                return NotFound($"General journal not found.");

            return Ok(incomingPayment);
        }


        [HttpPost("Save")]
        [DisplayName("Add/Edit Incoming Payment")]
        public IActionResult Save([FromBody] IncomingPaymentReq incomingPaymentReq)
        {
            return Ok(_incomingPaymentService.SaveIncomingPayment(incomingPaymentReq));
        }


        [HttpDelete("{id}")]
        [DisplayName("Delete Incoming Payment")]
        public IActionResult Delete(int id)
        {
            _incomingPaymentService.DeleteIncomingPayment(id);

            return Ok();
        }

        #endregion
    }
}
