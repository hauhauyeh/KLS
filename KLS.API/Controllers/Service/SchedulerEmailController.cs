using KLS.Common;
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
            _customerService.EmailPricesheet(payeeId, EmailAudit.Source.Scheduler);
            return Ok();
        }

        [HttpPost("statement/{payeeId}")]
        public IActionResult EmailStatement(int payeeId)
        {
            // 2026-08-28: surface send failure as non-2xx so the scheduler logs it per row.
            var result = _customerService.EmailStatement(payeeId, source: EmailAudit.Source.Scheduler);
            if (!result.Sent)
                throw new InvalidOperationException(result.Error ?? "Statement email failed.");
            return Ok();
        }

        [HttpPost("invoice/{salesId}")]
        public IActionResult EmailInvoice(int salesId)
        {
            // 2026-08-28: surface send failure as non-2xx so the scheduler logs it per row.
            var result = _salesService.EmailPdf(salesId, source: EmailAudit.Source.Scheduler);
            if (result.DeliveryStatus != EmailAudit.DeliveryStatus.Sent)
                throw new InvalidOperationException(result.ErrorMessage ?? "Invoice email failed.");
            return Ok();
        }

        #endregion
    }
}
