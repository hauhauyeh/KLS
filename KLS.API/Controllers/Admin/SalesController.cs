using KLS.API.Helpers;
using KLS.Contract.Services;
using KLS.Models;
using KLS.Services;
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel;
using System.ComponentModel.DataAnnotations;

namespace KLS.API.Controllers.Admin
{
    [AuthorizeAdmin]
    [Route("api/admin/[controller]")]
    [Display(Name = "Order Management", GroupName = "Customer")]
    public class SalesController : BaseController
    {
        #region --- Member(s) ---

        private readonly ISalesService _salesService;
        private readonly IWebHostEnvironment _env;

        #endregion

        #region --- Constructor(s) ---

        public SalesController(ISalesService salesService, IWebHostEnvironment env)
        {
            _salesService = salesService;
            _env = env;
        }

        #endregion

        #region --- Method(s) ---

        [HttpGet]
        [DisplayName("List Orders")]
        public IActionResult List([FromQuery] SalesListReq salesListReq)
        {
            return Ok(_salesService.GetPagedList(salesListReq));
        }


        [HttpGet("{salesId}")]
        public IActionResult GetById(int salesId)
        {
            var sales = _salesService.GetById(salesId);

            if (sales == null)
                return NotFound($"Sales with Id {salesId} not found.");

            return Ok(sales);
        }


        [HttpPut("UpdateRoute")]
        [DisplayName("Update Route")]
        public IActionResult UpdateRoute([FromBody] SalesUpdateReq updateReq)
        {
            return Ok(_salesService.UpdateShipRoute(updateReq.SalesId, updateReq.ShipRoute));
        }


        [HttpPut("UpdateStage")]
        [DisplayName("Update Stage")]
        public IActionResult UpdateStage([FromBody] SalesUpdateReq updateReq)
        {
            return Ok(_salesService.UpdateStage(updateReq.SalesId, updateReq.StageId.Value));
        }


        [HttpPut("UpdateInstruction")]
        [DisplayName("Update Instruction")]
        public IActionResult UpdateInstruction([FromBody] SalesUpdateReq updateReq)
        {
            _salesService.UpdateInstruction(updateReq.SalesId, updateReq.Instruction);
            return Ok();
        }


        [HttpPut("UpdatePO")]
        [DisplayName("Update PO")]
        public IActionResult UpdatePO([FromBody] SalesUpdateReq updateReq)
        {
            _salesService.UpdatePO(updateReq.SalesId, updateReq.CustPONumber);
            return Ok();
        }


        [HttpPut("UpdateLoadSeparate/{salesId}")]
        [DisplayName("Update Load Separate")]
        public IActionResult UpdateLoadSeparate(int salesId)
        {
            _salesService.UpdateLoadSeparate(salesId);
            return Ok();
        }


        [HttpPut("UpdateCarrier")]
        [DisplayName("Update Carrier")]
        public IActionResult UpdateCarrier([FromBody] SalesUpdateReq updateReq)
        {
            return Ok(_salesService.UpdateCarrier(updateReq.SalesId, updateReq.ShippingCarrierId));
        }


        [HttpDelete("{salesId}")]
        [DisplayName("Delete Order")]
        public IActionResult Delete(int salesId)
        {
            _salesService.Delete(salesId);
            return Ok();
        }


        [HttpGet("GetShipRoutes/{ShipDate}")]
        public IActionResult GetShipRoutes(DateOnly ShipDate)
        {
            return Ok(_salesService.GetShipRoutes(ShipDate));
        }


        [HttpGet("GetByDateRoute")]
        public IActionResult GetByDateRoute([FromQuery] SalesDateRouteReq dateRouteReq)
        {
            return Ok(_salesService.GetByDateRoute(dateRouteReq));
        }


        [HttpGet("SeePdf/{salesNumber}")]
        [DisplayName("See Pdf Image")]
        public IActionResult SeePdf(int salesNumber)
        {
            var filePath = Path.Combine(_env.WebRootPath, "InvoicePdf", salesNumber + ".pdf");

            if (!System.IO.File.Exists(filePath))
                return NotFound("File not found.");

            var fileStream = new FileStream(filePath, FileMode.Open, FileAccess.Read);
            return File(fileStream, "application/pdf");
        }


        [HttpPost("EmailPdf/{salesId}")]
        [DisplayName("Email Pdf Image")]
        public IActionResult EmailPdf(int salesId)
        {
            _salesService.EmailPdf(salesId);
            return Ok();
        }


        [HttpPost("Inject/{salesId}")]
        public IActionResult Inject(int salesId)
        {
            _salesService.Inject(salesId);
            return Ok();
        }


        [HttpPost("Checkout")]
        [DisplayName("Create Order")]
        public IActionResult Checkout([FromBody] SalesCheckoutReq checkoutReq)
        {
            return Ok(_salesService.Checkout(checkoutReq));
        }


        [HttpPut("UpdatePartially/{salesId}")]
        [DisplayName("Update Order")]
        public IActionResult UpdatePartially(int salesId)
        {
            return Ok(_salesService.UpdatePartially(salesId));
        }


        [HttpPut("UpdateNameDate")]
        public IActionResult UpdateNameDate([FromBody] SalesUpdateReq updateReq)
        {
            return Ok(_salesService.UpdateNameDate(updateReq));
        }


        [HttpPut("ShippingCharge")]
        [DisplayName("Add Shipping Charge")]
        public IActionResult ShippingCharge([FromBody] SalesUpdateReq updateReq)
        {
            return Ok(_salesService.InsertShippingCharge(updateReq));
        }


        [HttpPost("MergeOrder")]
        [DisplayName("Merge Order")]
        public IActionResult MergeOrder([FromBody] SalesMergeReq mergeReq)
        {
            return Ok(_salesService.MergeOrder(mergeReq));
        }


        [HttpPost("MergePdf")]
        [DisplayName("Merge Pdf")]
        public IActionResult MergePdf([FromQuery] string salesNumbers)
        {
            try
            {
                var filePath = _salesService.MergePdf(salesNumbers);

                var fileStream = new FileStream(filePath, FileMode.Open, FileAccess.Read);
                return File(fileStream, "application/pdf");
            }
            catch (Exception ex)
            {
                return BadRequest(ex.Message);
            }
        }


        [HttpGet("SeePayment/{salesId}")]
        [DisplayName("See Payment")]
        public IActionResult SeePayment(int salesId)
        {
            return Ok(_salesService.SeePayment(salesId));
        }


        [HttpGet("OpenInvoices/{payeeId}")]
        public IActionResult OpenInvoices(int payeeId)
        {
            return Ok(_salesService.OpenInvoices(payeeId));
        }


        [HttpGet("PastDueInvoices/{payeeId}")]
        public IActionResult PastDueInvoices(int payeeId)
        {
            return Ok(_salesService.PastDueInvoices(payeeId));
        }


        [HttpGet("Export")]
        [DisplayName("Export Order")]
        public IActionResult Export([FromQuery] SalesExportReq exportReq)
        {
            var bytes = _salesService.Export(exportReq);

            return File(
                bytes,
                "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
                $"Sales_{DateTime.Now:yyyyMMddHHmmss}.xlsx");
        }

        #endregion
    }
}
