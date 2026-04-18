using KLS.API.Helpers;
using KLS.Contract.Services;
using KLS.Models;
using Microsoft.AspNetCore.Mvc;
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

        #endregion

        #region --- Constructor(s) ---

        public DocumentsController(IDocumentService documentService)
        {
            _documentService = documentService;
        }

        #endregion

        #region --- Method(s) ---

        [HttpPost("SalesOrder")]
        public IActionResult SalesOrder([FromBody] DocumentReq documentReq)
        {
            var filePath = _documentService.SalesOrder(documentReq);

            if (!System.IO.File.Exists(filePath))
                return NotFound("File not found.");

            var fileStream = new FileStream(filePath, FileMode.Open, FileAccess.Read, FileShare.Read);
            return File(fileStream, "application/pdf");
        }


        [HttpPost("PickTicket")]
        public IActionResult PickTicket([FromBody] DocumentReq documentReq)
        {
            var filePath = _documentService.PickTicket(documentReq);

            if (!System.IO.File.Exists(filePath))
                return NotFound("File not found.");

            var fileStream = new FileStream(filePath, FileMode.Open, FileAccess.Read, FileShare.Read);
            return File(fileStream, "application/pdf");
        }


        [HttpPost("Invoice")]
        public IActionResult Invoice([FromBody] DocumentReq documentReq)
        {
            var filePath = _documentService.Invoice(documentReq);

            if (!System.IO.File.Exists(filePath))
                return NotFound("File not found.");

            var fileStream = new FileStream(filePath, FileMode.Open, FileAccess.Read, FileShare.Read);
            return File(fileStream, "application/pdf");
        }


        [HttpPost("PackingList")]
        public IActionResult PackingList([FromBody] DocumentReq documentReq)
        {
            var filePath = _documentService.PackingList(documentReq);

            if (!System.IO.File.Exists(filePath))
                return NotFound("File not found.");

            var fileStream = new FileStream(filePath, FileMode.Open, FileAccess.Read, FileShare.Read);
            return File(fileStream, "application/pdf");
        }

        [HttpPost("TotalList")]
        public IActionResult TotalList([FromBody] DocumentReq documentReq)
        {
            var filePath = _documentService.TotalList(documentReq);

            if (!System.IO.File.Exists(filePath))
                return NotFound("File not found.");

            var fileStream = new FileStream(filePath, FileMode.Open, FileAccess.Read, FileShare.Read);
            return File(fileStream, "application/pdf");
        }

        [HttpPost("TotalSplitList")]
        public IActionResult TotalSplitList([FromBody] DocumentReq documentReq)
        {
            var filePath = _documentService.TotalSplitList(documentReq);

            if (!System.IO.File.Exists(filePath))
                return NotFound("File not found.");

            var fileStream = new FileStream(filePath, FileMode.Open, FileAccess.Read, FileShare.Read);
            return File(fileStream, "application/pdf");
        }

        [HttpPost("HarvillsList")]
        public IActionResult HarvillsList([FromBody] DocumentReq documentReq)
        {
            var filePath = _documentService.HarvillsList(documentReq);

            if (!System.IO.File.Exists(filePath))
                return NotFound("File not found.");

            var fileStream = new FileStream(filePath, FileMode.Open, FileAccess.Read, FileShare.Read);
            return File(fileStream, "application/pdf");
        }

        [HttpPost("StoreTotalList")]
        public IActionResult StoreTotalList([FromBody] DocumentReq documentReq)
        {
            var filePath = _documentService.StoreTotalList(documentReq);

            if (!System.IO.File.Exists(filePath))
                return NotFound("File not found.");

            var fileStream = new FileStream(filePath, FileMode.Open, FileAccess.Read, FileShare.Read);
            return File(fileStream, "application/pdf");
        }


        [HttpPost("LoadingList")]
        public IActionResult LoadingList([FromBody] DocumentReq documentReq)
        {
            var filePath = _documentService.LoadingList(documentReq);

            if (!System.IO.File.Exists(filePath))
                return NotFound("File not found.");

            var fileStream = new FileStream(filePath, FileMode.Open, FileAccess.Read, FileShare.Read);
            return File(fileStream, "application/pdf");
        }


        [HttpPost("PackingLabel")]
        public IActionResult PackingLabel([FromBody] DocumentReq documentReq)
        {
            var filePath = _documentService.PackingLabel(documentReq);

            if (!System.IO.File.Exists(filePath))
                return NotFound("File not found.");

            var fileStream = new FileStream(filePath, FileMode.Open, FileAccess.Read, FileShare.Read);
            return File(fileStream, "application/pdf");
        }

        #endregion
    }
}
