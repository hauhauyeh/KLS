using KLS.API.Helpers;
using KLS.Contract.Services;
using KLS.Models;
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel.DataAnnotations;

namespace KLS.API.Controllers.Admin
{
    [AuthorizeAdmin]
    [Route("api/admin/[controller]")]
    [Display(Name = "Print Invoices Management", GroupName = "Customer")]
    public class SalesRoutesController : BaseController
    {
        #region --- Member(s) ---

        private readonly ISalesRouteService _salesRouteService;

        #endregion

        #region --- Constructor(s) ---

        public SalesRoutesController(ISalesRouteService salesRouteService)
        {
            _salesRouteService = salesRouteService;
        }

        #endregion

        #region --- Method(s) ---

        [HttpGet("GetAssignTrucks/{shipDate}")]
        public IActionResult GetAssignTrucks(DateOnly shipDate)
        {
            return Ok(_salesRouteService.GetAssignTrucks(shipDate));
        }


        [HttpPost("SaveAssignTrucks")]
        public IActionResult SaveAssignTrucks([FromBody] List<AssignTruck> assignTrucks)
        {
            _salesRouteService.SaveAssignTrucks(assignTrucks);
            return Ok();
        }


        [HttpPost("CheckZeroPrice")]
        public IActionResult CheckZeroPrice([FromBody] PrintInvoiceReq printInvoiceReq)
        {
            return Ok(_salesRouteService.CheckZeroPrice(printInvoiceReq));
        }

        #endregion
    }
}
