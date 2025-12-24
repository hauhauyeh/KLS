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
    [Display(Name = "Sales Management", GroupName = "Customer")]
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
        [DisplayName("Order Manager")]
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


        [HttpDelete("{salesId}")]
        [DisplayName("Delete Sales")]
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


        [HttpGet("SeePDF/{salesNumber}")]
        [DisplayName("See PDF Image")]
        public IActionResult SeePdf(int salesNumber)
        {
            var filePath = Path.Combine(_env.WebRootPath, "InvoicePdf", salesNumber + ".pdf");

            if (!System.IO.File.Exists(filePath))
                return NotFound("File not found.");

            var fileStream = new FileStream(filePath, FileMode.Open, FileAccess.Read);
            return File(fileStream, "application/pdf");
        }

        #endregion
    }
}
