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
    [Display(Name = "Temp Sales Quote", GroupName = "Customer")]
    public class TempSalesQuoteController : BaseController
    {
        private readonly ITempSalesQuoteService _service;

        public TempSalesQuoteController(ITempSalesQuoteService service)
        {
            _service = service;
        }

        [HttpGet]
        public IActionResult GetList([FromQuery] TempSalesQuoteReq req)
        {
            return Ok(_service.GetList(req));
        }

        [HttpPost]
        public IActionResult Create([FromBody] TempSalesQuoteItem item)
        {
            return Ok(_service.Create(item));
        }

        [HttpPut]
        public IActionResult Update([FromBody] TempSalesQuoteItem item)
        {
            return Ok(_service.Update(item));
        }

        [HttpPut("Unit")]
        public IActionResult UpdateUnit([FromBody] TempSalesQuoteItem item)
        {
            return Ok(_service.UpdateUnit(item));
        }

        [HttpDelete("{id}")]
        public IActionResult Delete(int id)
        {
            _service.Delete(id);
            return Ok();
        }

        [HttpPost("Clear")]
        public IActionResult Clear([FromBody] TempSalesQuoteReq req)
        {
            _service.Clear(req);
            return Ok();
        }

        [HttpGet("Search")]
        public IActionResult Search([FromQuery] TempSalesQuoteReq req)
        {
            return Ok(_service.Search(req));
        }

        [HttpPost("AddLine")]
        public IActionResult AddLine([FromBody] SalesQuoteAddLineRequest req)
        {
            return Ok(_service.AddLine(req));
        }
    }
}
