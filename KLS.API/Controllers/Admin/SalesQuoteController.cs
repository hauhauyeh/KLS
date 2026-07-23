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
    [Display(Name = "Sales Quote", GroupName = "Customer")]
    public class SalesQuoteController : BaseController
    {
        private readonly ISalesQuoteService _service;

        public SalesQuoteController(ISalesQuoteService service)
        {
            _service = service;
        }

        [HttpGet]
        [DisplayName("List Quotes")]
        [PermissionKey("Customer.SalesQuote.List")]
        public IActionResult List([FromQuery] SalesQuoteListReq req)
        {
            return Ok(_service.GetPagedList(req));
        }

        [HttpGet("{id}")]
        public IActionResult GetById(int id)
        {
            var quote = _service.GetById(id);
            if (quote == null) return NotFound();
            return Ok(quote);
        }

        [HttpGet("Detail/{id}")]
        [PermissionKey("Customer.SalesQuote.List")]
        public IActionResult Detail(int id)
        {
            return Ok(_service.GetDetail(id));
        }

        [HttpGet("EmailContext/{id}")]
        [DisplayName("Quote Email Context")]
        [PermissionKey("Customer.SalesQuote.EmailPdf")]
        public IActionResult EmailContext(int id)
        {
            var context = _service.GetEmailContext(id);
            if (context == null) return NotFound();
            return Ok(context);
        }

        [HttpPost("Insert")]
        [DisplayName("Create Quote")]
        [PermissionKey("Customer.SalesQuote.Create")]
        public IActionResult Insert([FromBody] SalesQuoteSaveReq req)
        {
            return Ok(_service.Insert(0, req.PayeeId, req.ExpiryDate, req.Notes, req.StatusId));
        }

        [HttpPut("Update/{id}")]
        [DisplayName("Update Quote")]
        [PermissionKey("Customer.SalesQuote.Update")]
        public IActionResult Update(int id, [FromBody] SalesQuoteSaveReq req)
        {
            _service.Update(id, req.PayeeId, req.ExpiryDate, req.Notes);
            return Ok();
        }

        [HttpPost("Inject/{id}")]
        [DisplayName("Edit Quote")]
        [PermissionKey("Customer.SalesQuote.Update")]
        public IActionResult Inject(int id)
        {
            _service.Inject(id);
            return Ok();
        }

        [HttpDelete("{id}")]
        [DisplayName("Delete Quote")]
        [PermissionKey("Customer.SalesQuote.Delete")]
        public IActionResult Delete(int id)
        {
            _service.Delete(id);
            return Ok();
        }

        [HttpPut("UpdateStatus")]
        [DisplayName("Update Quote Status")]
        [PermissionKey("Customer.SalesQuote.UpdateStatus")]
        public IActionResult UpdateStatus([FromBody] SalesQuoteStatusReq req)
        {
            _service.UpdateStatus(req.SalesQuoteId, req.StatusId);
            return Ok();
        }

        [HttpPost("ConvertToSales/{id}")]
        [DisplayName("Convert to Sales Order")]
        [PermissionKey("Customer.SalesQuote.ConvertToSales")]
        public IActionResult ConvertToSales(int id)
        {
            return Ok(_service.ConvertToSales(id));
        }

        [HttpPost("EmailPdf/{id}")]
        [DisplayName("Email Quote PDF")]
        [PermissionKey("Customer.SalesQuote.EmailPdf")]
        public IActionResult EmailPdf(int id, [FromBody] SalesQuoteEmailPdfReq? req)
        {
            _service.EmailPdf(id, req);
            return Ok();
        }
    }
}
