using KLS.API.Helpers;
using KLS.Contract.Services;
using KLS.Models;
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel.DataAnnotations;

namespace KLS.API.Controllers.Admin
{
    [AuthorizeAdmin]
    [Route("api/admin/[controller]")]
    [Display(Name = "Return Item Management", GroupName = "Customer")]
    public class SalesRouteDetailsController : BaseController
    {
        #region --- Member(s) ---

        private readonly ISalesRouteDetailService _salesRouteDetailService;

        #endregion

        #region --- Constructor(s) ---

        public SalesRouteDetailsController(ISalesRouteDetailService salesRouteDetailService)
        {
            _salesRouteDetailService = salesRouteDetailService;
        }

        #endregion

        #region --- Method(s) ---

        [HttpGet("{salesRouteId}")]
        public IActionResult List(int salesRouteId)
        {
            return Ok(_salesRouteDetailService.GetList(salesRouteId));
        }

        [HttpGet("UntrackedPending")]
        [PermissionKey("Customer.Sale.List")]
        public IActionResult UntrackedPending()
        {
            return Ok(_salesRouteDetailService.GetPendingUntracked());
        }

        [HttpGet("Pending")]
        [PermissionKey("Customer.Sale.List")]
        public IActionResult Pending([FromQuery] UntrackReturnListReq req)
        {
            return Ok(_salesRouteDetailService.GetPendingUntrackedPaged(req));
        }


        [HttpPost]
        public IActionResult Create([FromBody] SalesRouteDetail routeDetail)
        {
            return Ok(_salesRouteDetailService.Create(routeDetail));
        }


        [HttpPut]
        public IActionResult Update([FromBody] SalesRouteDetail routeDetail)
        {
            return Ok(_salesRouteDetailService.Update(routeDetail));
        }


        [HttpPut("UpdateUnit")]
        public IActionResult UpdateUnit([FromBody] SalesRouteDetail routeDetail)
        {
            return Ok(_salesRouteDetailService.UpdateUnit(routeDetail));
        }


        [HttpPost("Restock/{detailId}")]
        [PermissionKey("Product.InventoryAdj.Save")]
        public IActionResult Restock(int detailId)
        {
            return Ok(_salesRouteDetailService.Restock(detailId));
        }


        [HttpDelete("{detailId}")]
        public IActionResult Delete(int detailId)
        {
            _salesRouteDetailService.Delete(detailId);
            return Ok();
        }

        #endregion
    }
}
