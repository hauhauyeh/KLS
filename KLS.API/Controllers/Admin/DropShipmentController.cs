using KLS.API.Helpers;
using KLS.Contract.Dtos.DropShipment;
using KLS.Contract.Services;
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel;
using System.ComponentModel.DataAnnotations;

namespace KLS.API.Controllers.Admin
{
    [AuthorizeAdmin]
    [Route("api/admin/[controller]")]
    [Display(Name = "Drop Shipment", GroupName = "Vendor")]
    public class DropShipmentController : BaseController
    {
        #region --- Member(s) ---

        private readonly IDropShipmentService _dropShipmentService;

        #endregion

        #region --- Constructor(s) ---

        public DropShipmentController(IDropShipmentService dropShipmentService)
        {
            _dropShipmentService = dropShipmentService;
        }

        #endregion

        #region --- Method(s) ---

        [HttpPost("InsertSalesAndPO")]
        [DisplayName("Create Drop Ship Order")]
        [PermissionKey("Vendor.DropShipment.Create")]
        public IActionResult InsertSalesAndPO([FromBody] DropShipmentInsertReq req)
        {
            return Ok(_dropShipmentService.InsertSalesAndPO(req));
        }


        [HttpPost("UpdateShipQty")]
        [DisplayName("Update Ship Qty")]
        [PermissionKey("Vendor.DropShipment.UpdateShipQty")]
        public IActionResult UpdateShipQty([FromBody] DropShipmentUpdateShipQtyReq req)
        {
            _dropShipmentService.UpdateShipQty(req);
            return Ok();
        }


        [HttpPost("ConvertPOToBill")]
        [DisplayName("Convert PO to Bill")]
        [PermissionKey("Vendor.DropShipment.ConvertToBill")]
        public IActionResult ConvertPOToBill([FromBody] DropShipmentConvertReq req)
        {
            _dropShipmentService.ConvertPOToBill(req);
            return Ok();
        }

        #endregion
    }
}
