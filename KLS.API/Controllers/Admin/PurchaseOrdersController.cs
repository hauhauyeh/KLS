using KLS.API.Helpers;
using KLS.Models;
using KLS.Services;
using KLS.Services.Interfaces;
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel;
using System.ComponentModel.DataAnnotations;

namespace KLS.API.Controllers.Admin
{
    //[AuthorizeAdmin]
    [Route("api/admin/[controller]")]
    [Display(Name = "PurchaseOrder Management", GroupName = "Admin")]
    public class PurchaseOrdersController : BaseController
    {
        #region --- Member(s) ---

        private readonly IPurchaseOrderService _purchaseOrderService;

        #endregion

        #region --- Constructor(s) ---

        public PurchaseOrdersController(IPurchaseOrderService purchaseOrderService)
        {
            _purchaseOrderService = purchaseOrderService;
        }

        #endregion

        #region --- Method(s) ---

        [HttpGet]
        [DisplayName("List PurchaseOrders")]
        public IActionResult List([FromQuery] PurchaseOrderReq purchaseOrderReq)
        {
            return Ok(_purchaseOrderService.GetPurchaseOrders(purchaseOrderReq));
        }


        [HttpPost("UpdateNotes")]
        public IActionResult UpdateNotes([FromBody] PurchaseOrder purchaseOrder)
        {
            _purchaseOrderService.UpdateNotes(purchaseOrder);

            return Ok();
        }


        [HttpPost("UpdateVendorDocNumber")]
        public IActionResult UpdateVendorDocNumber([FromBody] PurchaseOrder purchaseOrder)
        {
            _purchaseOrderService.UpdateVendorDocNumber(purchaseOrder);

            return Ok();
        }

        #endregion
    }
}
