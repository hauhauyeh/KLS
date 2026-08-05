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
    [Display(Name = "Print Document Management", GroupName = "Customer")]
    public class DocumentsController : BaseController
    {
        #region --- Member(s) ---

        private readonly IDocumentService _documentService;
        private readonly ISalesOrderDocumentStageEffectService _salesOrderDocumentStageEffectService;

        #endregion

        #region --- Constructor(s) ---

        public DocumentsController(
            IDocumentService documentService,
            ISalesOrderDocumentStageEffectService salesOrderDocumentStageEffectService)
        {
            _documentService = documentService;
            _salesOrderDocumentStageEffectService = salesOrderDocumentStageEffectService;
        }

        #endregion

        #region --- Method(s) ---

        [HttpPost("SalesOrder")]
        [DisplayName("Gen Sales Order")]
        [PermissionKey("Customer.Sale.SalesOrder")]
        public IActionResult SalesOrder([FromBody] DocumentReq documentReq)
        {
            var filePath = _documentService.SalesOrder(documentReq);

            if (!System.IO.File.Exists(filePath))
                return NotFound("File not found.");

            var fileStream = new FileStream(filePath, FileMode.Open, FileAccess.Read, FileShare.Read);
            return File(fileStream, "application/pdf");
        }


        [HttpPost("PickTicket")]
        [DisplayName("Gen Pick Ticket")]
        [PermissionKey("Customer.Sale.PickTicket")]
        public IActionResult PickTicket([FromBody] DocumentReq documentReq)
        {
            var filePath = _documentService.PickTicket(documentReq);

            if (!System.IO.File.Exists(filePath))
                return NotFound("File not found.");

            if (!documentReq.IsPrint && documentReq.SalesId.HasValue)
                _salesOrderDocumentStageEffectService.ApplyAfterSuccess(
                    documentReq.SalesId.Value,
                    KLS.Common.SalesOrderDocumentActionKeys.GenPickTicket);

            var fileStream = new FileStream(filePath, FileMode.Open, FileAccess.Read, FileShare.Read);
            return File(fileStream, "application/pdf");
        }


        [HttpPost("Invoice")]
        [DisplayName("Gen Invoice")]
        [PermissionKey("Customer.Sale.Invoice")]
        public IActionResult Invoice([FromBody] DocumentReq documentReq)
        {
            var filePath = _documentService.Invoice(documentReq);

            if (!System.IO.File.Exists(filePath))
                return NotFound("File not found.");

            var fileStream = new FileStream(filePath, FileMode.Open, FileAccess.Read, FileShare.Read);
            return File(fileStream, "application/pdf");
        }


        [HttpPost("PackingList")]
        [DisplayName("Gen Packing List")]
        [PermissionKey("Customer.Sale.PackingList")]
        public IActionResult PackingList([FromBody] DocumentReq documentReq)
        {
            var filePath = _documentService.PackingList(documentReq);

            if (!System.IO.File.Exists(filePath))
                return NotFound("File not found.");

            var fileStream = new FileStream(filePath, FileMode.Open, FileAccess.Read, FileShare.Read);
            return File(fileStream, "application/pdf");
        }

        [HttpPost("TotalList")]
        [DisplayName("Gen Checking List")]
        [PermissionKey("Customer.Sale.CheckingList")]
        public IActionResult TotalList([FromBody] DocumentReq documentReq)
        {
            var filePath = _documentService.TotalList(documentReq);

            if (!System.IO.File.Exists(filePath))
                return NotFound("File not found.");

            var fileStream = new FileStream(filePath, FileMode.Open, FileAccess.Read, FileShare.Read);
            return File(fileStream, "application/pdf");
        }

        [HttpPost("TotalSplitList")]
        [DisplayName("Gen Total Split")]
        [PermissionKey("Customer.Sale.TotalSplit")]
        public IActionResult TotalSplitList([FromBody] DocumentReq documentReq)
        {
            var filePath = _documentService.TotalSplitList(documentReq);

            if (!System.IO.File.Exists(filePath))
                return NotFound("File not found.");

            var fileStream = new FileStream(filePath, FileMode.Open, FileAccess.Read, FileShare.Read);
            return File(fileStream, "application/pdf");
        }

        [HttpPost("HarvillsList")]
        [DisplayName("Gen Harvills List")]
        [PermissionKey("Customer.Sale.HarvillsList")]
        public IActionResult HarvillsList([FromBody] DocumentReq documentReq)
        {
            var filePath = _documentService.HarvillsList(documentReq);

            if (!System.IO.File.Exists(filePath))
                return NotFound("File not found.");

            var fileStream = new FileStream(filePath, FileMode.Open, FileAccess.Read, FileShare.Read);
            return File(fileStream, "application/pdf");
        }

        [HttpPost("StoreTotalList")]
        [DisplayName("Gen StoreTotal List")]
        [PermissionKey("Customer.Sale.StoreTotalList")]
        public IActionResult StoreTotalList([FromBody] DocumentReq documentReq)
        {
            var filePath = _documentService.StoreTotalList(documentReq);

            if (!System.IO.File.Exists(filePath))
                return NotFound("File not found.");

            var fileStream = new FileStream(filePath, FileMode.Open, FileAccess.Read, FileShare.Read);
            return File(fileStream, "application/pdf");
        }


        [HttpPost("LoadingList")]
        [DisplayName("Gen Loading List")]
        [PermissionKey("Customer.Sale.LoadingList")]
        public IActionResult LoadingList([FromBody] DocumentReq documentReq)
        {
            var filePath = _documentService.LoadingList(documentReq);

            if (!System.IO.File.Exists(filePath))
                return NotFound("File not found.");

            var fileStream = new FileStream(filePath, FileMode.Open, FileAccess.Read, FileShare.Read);
            return File(fileStream, "application/pdf");
        }

        [HttpPost("RouteLoadingList")]
        [DisplayName("Gen Route Loading List")]
        [PermissionKey("Customer.Sale.LoadingList")]
        public IActionResult RouteLoadingList([FromBody] DocumentReq documentReq)
        {
            var filePath = _documentService.RouteLoadingList(documentReq);

            if (!System.IO.File.Exists(filePath))
                return NotFound("File not found.");

            var fileStream = new FileStream(filePath, FileMode.Open, FileAccess.Read, FileShare.Read);
            return File(fileStream, "application/pdf");
        }


        [HttpPost("PackingLabel")]
        [DisplayName("Gen Packing Label")]
        [PermissionKey("Customer.Sale.PackingLabel")]
        public IActionResult PackingLabel([FromBody] DocumentReq documentReq)
        {
            var filePath = _documentService.PackingLabel(documentReq);

            if (!System.IO.File.Exists(filePath))
                return NotFound("File not found.");

            var fileStream = new FileStream(filePath, FileMode.Open, FileAccess.Read, FileShare.Read);
            return File(fileStream, "application/pdf");
        }


        [HttpGet("Check/{vendorPaymentId}")]
        [DisplayName("Print Check")]
        [PermissionKey("Vendor.VendorPayment.PrintCheck")]
        public IActionResult Check(int vendorPaymentId)
        {
            var filePath = _documentService.Check(vendorPaymentId);

            if (!System.IO.File.Exists(filePath))
                return NotFound("File not found.");

            var fileStream = new FileStream(filePath, FileMode.Open, FileAccess.Read, FileShare.Read);
            return File(fileStream, "application/pdf");
        }

        [HttpPost("SalesQuote/{id}")]
        [DisplayName("Gen Sales Quote")]
        [PermissionKey("Customer.SalesQuote.SeePdf")]
        public IActionResult SalesQuote(int id)
        {
            var filePath = _documentService.SalesQuote(id);

            if (!System.IO.File.Exists(filePath))
                return NotFound("File not found.");

            var fileStream = new FileStream(filePath, FileMode.Open, FileAccess.Read, FileShare.Read);
            return File(fileStream, "application/pdf");
        }

        #endregion
    }
}
