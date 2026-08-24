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
        [PermissionKey("Customer.Sale.List")]
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

        [HttpGet("Detail/{salesId}")]
        [DisplayName("Quick View Order")]
        [PermissionKey("Customer.Sale.List")]
        public IActionResult Detail(int salesId)
        {
            return Ok(_salesService.GetSalesDetails(salesId));
        }


        [HttpPut("UpdateRoute")]
        [DisplayName("Update Route")]
        [PermissionKey("Customer.Sale.UpdateRoute")]
        public IActionResult UpdateRoute([FromBody] SalesUpdateReq updateReq)
        {
            return Ok(_salesService.UpdateShipRoute(updateReq.SalesId, updateReq.ShipRoute));
        }


        [HttpPut("UpdateStage")]
        [DisplayName("Update Stage")]
        [PermissionKey("Customer.Sale.UpdateStage")]
        [SuperAdminOnly]
        public IActionResult UpdateStage([FromBody] SalesUpdateReq updateReq)
        {
            if (!updateReq.StageId.HasValue)
                return BadRequest("StageId is required.");

            return Ok(_salesService.UpdateStage(updateReq.SalesId, updateReq.StageId.Value));
        }


        [HttpPut("EnterEditMode")]
        [DisplayName("Enter Edit Mode")]
        [PermissionKey("Customer.Sale.Update")]
        public IActionResult EnterEditMode([FromBody] SalesStageTransitionReq transitionReq)
        {
            return Ok(_salesService.EnterEditMode(transitionReq.SalesId));
        }


        [HttpPut("RestoreStage")]
        [DisplayName("Restore Stage")]
        [PermissionKey("Customer.Sale.Update")]
        public IActionResult RestoreStage([FromBody] SalesStageTransitionReq transitionReq)
        {
            if (!transitionReq.StageId.HasValue)
                return BadRequest("StageId is required.");

            return Ok(_salesService.RestoreStage(transitionReq.SalesId, transitionReq.StageId.Value));
        }


        [HttpPut("UpdateInstruction")]
        [DisplayName("Update Instruction")]
        [PermissionKey("Customer.Sale.UpdateInstruction")]
        public IActionResult UpdateInstruction([FromBody] SalesUpdateReq updateReq)
        {
            _salesService.UpdateInstruction(updateReq.SalesId, updateReq.Instruction);
            return Ok();
        }


        [HttpPut("UpdatePO")]
        [DisplayName("Update PO")]
        [PermissionKey("Customer.Sale.UpdatePO")]
        public IActionResult UpdatePO([FromBody] SalesUpdateReq updateReq)
        {
            _salesService.UpdatePO(updateReq.SalesId, updateReq.CustPONumber);
            return Ok();
        }


        [HttpPut("UpdateLoadSeparate/{salesId}")]
        [DisplayName("Update Load Separate")]
        [PermissionKey("Customer.Sale.UpdateLoadSeparate")]
        public IActionResult UpdateLoadSeparate(int salesId)
        {
            _salesService.UpdateLoadSeparate(salesId);
            return Ok();
        }


        [HttpPut("UpdateCarrier")]
        [DisplayName("Update Carrier")]
        [PermissionKey("Customer.Sale.UpdateCarrier")]
        public IActionResult UpdateCarrier([FromBody] SalesUpdateReq updateReq)
        {
            return Ok(_salesService.UpdateCarrier(updateReq.SalesId, updateReq.ShippingCarrierId));
        }


        [HttpDelete("{salesId}")]
        [DisplayName("Delete Order")]
        [PermissionKey("Customer.Sale.Delete")]
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
        [PermissionKey("Customer.Sale.SeePdf")]
        public IActionResult SeePdf(int salesNumber)
        {
            _salesService.EnsureVisibleSalesNumber(salesNumber);

            var filePath = Path.Combine(_env.WebRootPath, "InvoicePdf", salesNumber + ".pdf");

            if (!System.IO.File.Exists(filePath))
                return NotFound("File not found.");

            var fileStream = new FileStream(filePath, FileMode.Open, FileAccess.Read);
            return File(fileStream, "application/pdf");
        }

        [HttpPost("UploadPdf")]
        [DisplayName("Upload Pdf Image")]
        [PermissionKey("Customer.Sale.UploadPdf")]
        public IActionResult UploadPdf([FromForm] SalesPDFUploadReq uploadReq)
        {
            _salesService.UploadPdf(uploadReq);

            return Ok();
        }

        [HttpPost("DeletePdfPages")]
        [DisplayName("Manage Pdf Pages")]
        [PermissionKey("Customer.Sale.ManagePdfPages")]
        public IActionResult DeletePdfPages([FromBody] SalesPdfPageDeleteReq deleteReq)
        {
            return Ok(_salesService.DeletePdfPages(deleteReq));
        }


        [HttpPost("EmailPdf/{salesId}")]
        [DisplayName("Email Invoice")]
        [PermissionKey("Customer.Sale.EmailPdf")]
        public IActionResult EmailPdf(int salesId, [FromBody] SalesEmailInvoiceReq? req)
        {
            return Ok(_salesService.EmailPdf(salesId, req));
        }

        [HttpPost("EmailDocument/{salesId}")]
        [DisplayName("Email Sales Document")]
        [PermissionKey("Customer.Sale.EmailPdf")]
        public IActionResult EmailDocument(int salesId, [FromBody] SalesEmailDocumentReq req)
        {
            return Ok(_salesService.EmailDocument(salesId, req));
        }

        [HttpGet("EmailPdfRecipient/{salesId}")]
        [DisplayName("Email Invoice")]
        [PermissionKey("Customer.Sale.EmailPdf")]
        public IActionResult EmailPdfRecipient(int salesId)
        {
            return Ok(_salesService.GetEmailInvoiceRecipient(salesId));
        }


        [HttpPost("Inject/{salesId}")]
        public IActionResult Inject(int salesId)
        {
            _salesService.Inject(salesId);
            return Ok();
        }


        [HttpPost("Checkout")]
        [DisplayName("Create Order")]
        [PermissionKey("Customer.Sale.Create")]
        public IActionResult Checkout([FromBody] SalesCheckoutReq checkoutReq)
        {
            return Ok(_salesService.Checkout(checkoutReq));
        }


        [HttpPut("UpdatePartially/{salesId}")]
        [DisplayName("Update Order")]
        [PermissionKey("Customer.Sale.Update")]
        public IActionResult UpdatePartially(int salesId)
        {
            return Ok(_salesService.UpdatePartially(salesId));
        }

        [HttpPut("DropShipRestrictedUpdate/{salesId}")]
        [DisplayName("Update Drop Ship Sales Details")]
        [PermissionKey("Customer.Sale.Update")]
        public IActionResult DropShipRestrictedUpdate(int salesId)
        {
            return Ok(_salesService.DropShipRestrictedUpdate(salesId));
        }


        [HttpPut("UpdateNameDate")]
        public IActionResult UpdateNameDate([FromBody] SalesUpdateReq updateReq)
        {
            return Ok(_salesService.UpdateNameDate(updateReq));
        }


        [HttpPut("ShippingCharge")]
        [DisplayName("Add Shipping Charge")]
        [PermissionKey("Customer.Sale.ShippingCharge")]
        public IActionResult ShippingCharge([FromBody] SalesUpdateReq updateReq)
        {
            return Ok(_salesService.InsertShippingCharge(updateReq));
        }


        [HttpPost("MergeOrder")]
        [DisplayName("Merge Order")]
        [PermissionKey("Customer.Sale.MergeOrder")]
        public IActionResult MergeOrder([FromBody] SalesMergeReq mergeReq)
        {
            return Ok(_salesService.MergeOrder(mergeReq));
        }


        [HttpPost("MergePdf")]
        [DisplayName("Merge Pdf")]
        [PermissionKey("Customer.Sale.MergePdf")]
        public IActionResult MergePdf([FromQuery] string salesNumbers)
        {
            try
            {
                var filePath = _salesService.MergePdf(salesNumbers);

                var fileStream = new FileStream(filePath, FileMode.Open, FileAccess.Read);
                return File(fileStream, "application/pdf");
            }
            catch (ArgumentException)
            {
                throw;
            }
            catch (KeyNotFoundException)
            {
                throw;
            }
            catch (UnauthorizedAccessException)
            {
                throw;
            }
            catch (Exception ex)
            {
                return BadRequest(ex.Message);
            }
        }


        [HttpGet("SeePayment/{salesId}")]
        [DisplayName("See Payment")]
        [PermissionKey("Customer.Sale.SeePayment")]
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

        [HttpGet("CustBoughtItemsPanel/{payeeId}")]
        public IActionResult CustBoughtItemsPanel(int payeeId)
        {
            return Ok(_salesService.CustBoughtItemsPanel(payeeId));
        }

        #endregion
    }
}
