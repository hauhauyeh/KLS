using KLS.API.Helpers;
using KLS.Contract.Services;
using KLS.Models;
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel.DataAnnotations;

namespace KLS.API.Controllers.Admin
{
    [AuthorizeAdmin]
    [Route("api/admin/[controller]")]
    [Display(Name = "Sales Routing Management", GroupName = "Customer")]
    public class SalesRoutingController : BaseController
    {
        #region --- Member(s) ---

        private readonly ISalesService _salesService;

        #endregion

        #region --- Constructor(s) ---

        public SalesRoutingController(ISalesService salesService)
        {
            _salesService = salesService;
        }

        #endregion

        #region --- Method(s) ---

        [HttpGet("ShipRouteSummary/{shipDate}")]
        public IActionResult ShipRouteSummary(DateOnly shipDate)
        {
            return Ok(_salesService.ShipRouteSummary(shipDate));
        }


        [HttpPut("UpdateRoute")]
        public IActionResult UpadteRoute([FromBody] List<ShipRouteDetail> routeDetails)
        {
            _salesService.UpdateRoute(routeDetails);
            return Ok();
        }


        [HttpPut("UpdateRouteOrder")]
        public IActionResult UpadteRouteOrder([FromBody] List<ShipRouteDetail> routeDetails)
        {
            _salesService.UpdateRouteOrder(routeDetails);
            return Ok();
        }

        #endregion
    }
}
