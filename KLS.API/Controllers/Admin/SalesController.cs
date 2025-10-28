using KLS.API.Helpers;
using KLS.Models;
using KLS.Services.Interfaces;
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

        #endregion

        #region --- Constructor(s) ---

        public SalesController(ISalesService salesService)
        {
            _salesService = salesService;
        }

        #endregion

        #region --- Method(s) ---

        [HttpGet]
        [DisplayName("Order Manager")]
        public IActionResult List([FromQuery] SalesListReq salesListReq)
        {
            return Ok(_salesService.GetAllSales(salesListReq));
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
            _salesService.DeleteSales(salesId);
            return Ok();
        }


        [HttpGet("GetShipRoutes/{ShipDate}")]
        public IActionResult GetShipRoutes(DateOnly ShipDate)
        {
            return Ok(_salesService.GetShipRoutes(ShipDate));
        }

        #endregion
    }
}
