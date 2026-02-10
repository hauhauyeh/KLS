using KLS.API.Helpers;
using KLS.Contract.Services;
using KLS.Models;
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel.DataAnnotations;

namespace KLS.API.Controllers.Admin
{
    [AuthorizeAdmin]
    [Route("api/admin/[controller]")]
    [Display(Name = "Extra Payment Management", GroupName = "Customer")]
    public class TempExtraPaymentsController : BaseController
    {
        #region --- Member(s) ---

        private readonly ITempExtraPaymentService _tempExtraPaymentService;

        #endregion

        #region --- Constructor(s) ---

        public TempExtraPaymentsController(ITempExtraPaymentService tempExtraPaymentService)
        {
            _tempExtraPaymentService = tempExtraPaymentService;
        }

        #endregion

        #region --- Method(s) ---

        [HttpPost]
        public IActionResult Create([FromBody] TempExtraPayment extraPayment)
        {
            return Ok(_tempExtraPaymentService.Create(extraPayment));
        }


        [HttpPut]
        public IActionResult Update([FromBody] TempExtraPayment extraPayment)
        {
            _tempExtraPaymentService.Update(extraPayment);
            return Ok();
        }

        #endregion
    }
}
