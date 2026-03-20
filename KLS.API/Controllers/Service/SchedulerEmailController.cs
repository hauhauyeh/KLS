using KLS.Contract.Services;
using Microsoft.AspNetCore.Mvc;

namespace KLS.API.Controllers.Service
{
    [Route("api/service/[controller]")]
    public class SchedulerEmailController : BaseController
    {
        #region --- Member(s) ---

        private readonly ICustomerService _customerService;
        private readonly ISalesService _salesService;

        #endregion

        #region --- Constructor(s) ---

        public SchedulerEmailController(ICustomerService customerService, ISalesService salesService)
        {
            _customerService = customerService;
            _salesService = salesService;
        }

        #endregion

        #region --- Method(s) ---

        [HttpPost("pricesheet/{payeeId}")]
        public IActionResult EmailPricesheet(int payeeId)
        {
            _customerService.EmailPricesheet(payeeId);
            return Ok();
        }

        [HttpPost("statement/{payeeId}")]
        public IActionResult EmailStatement(int payeeId)
        {
            _customerService.EmailStatement(payeeId);
            return Ok();
        }

        [HttpPost("invoice/{salesId}")]
        public IActionResult EmailInvoice(int salesId)
        {
            _salesService.EmailPdf(salesId);
            return Ok();
        }

        #endregion
    }
}
