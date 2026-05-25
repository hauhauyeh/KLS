using KLS.API.Helpers;
using KLS.Common;
using KLS.Contract.Services;
using KLS.Models;
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel;

namespace KLS.API.Controllers.Web
{
    [AuthorizeWeb]
    [Route("api/web/[controller]")]
    public class OrdersController : BaseController
    {
        #region --- Member(s) ---

        private readonly ISalesService _salesService;
        private readonly IDocumentService _documentService;
        private readonly IWebHostEnvironment _env;

        #endregion

        #region --- Constructor(s) ---

        public OrdersController(ISalesService salesService, IDocumentService documentService, IWebHostEnvironment env)
        {
            _salesService = salesService;
            _documentService = documentService;
            _env = env;
        }

        #endregion

        #region --- Method(s) ---

        [HttpGet]
        [DisplayName("List Orders")]
        public IActionResult List([FromQuery] SalesListReq salesListReq)
        {
            return Ok(_salesService.GetWebPagedList(salesListReq));
        }


        [HttpGet("SeePdf/{salesNumber}")]
        public IActionResult SeePdf(int salesNumber)
        {
            var sales = _salesService.GetBySalesNumber(salesNumber);

            if (sales?.ShipId != UserContext.EmpId)
                return NotFound("File not found.");

            var filePath = Path.Combine(_env.WebRootPath, "InvoicePdf", salesNumber + ".pdf");

            if (System.IO.File.Exists(filePath))
            {
                var fileStream = new FileStream(filePath, FileMode.Open, FileAccess.Read);
                return File(fileStream, "application/pdf");
            }

            // Fallback: generate invoice PDF on-the-fly
            var generatedPath = _documentService.Invoice(new DocumentReq { SalesId = sales.SalesId, SalesNumber = sales.SalesNumber });

            if (string.IsNullOrEmpty(generatedPath) || !System.IO.File.Exists(generatedPath))
                return NotFound("File not found.");

            var generatedStream = new FileStream(generatedPath, FileMode.Open, FileAccess.Read, FileShare.Read);
            return File(generatedStream, "application/pdf");
        }


        [HttpGet("Details/{salesId}")]
        public IActionResult Details(int salesId)
        {
            var detail = _salesService.GetSalesDetails(salesId);

            if (detail?.Sales?.ShipId != UserContext.EmpId)
                return Forbid("You are not authorized to view this order.");

            return Ok(detail);
        }


        [HttpPost("Checkout")]
        public IActionResult Checkout([FromBody] SalesWebCheckoutReq webCheckoutReq)
        {
            var salesId = _salesService.WebCheckout(webCheckoutReq);
            return Ok(new { SalesId = salesId });
        }


        [HttpPost("CheckoutB2C")]
        public IActionResult CheckoutB2C([FromBody] SalesB2cCheckoutReq webCheckoutReq)
        {
            var salesId = _salesService.WebCheckoutB2C(webCheckoutReq);
            return Ok(new { SalesId = salesId });
        }

        #endregion
    }
}
