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


        [HttpPost("GeneratePOFromSales")]
        [DisplayName("Generate Drop-Ship PO from Sales Order")]
        [PermissionKey("Vendor.DropShipment.Create")]
        public IActionResult GeneratePOFromSales([FromBody] DropShipmentGeneratePoReq req)
        {
            return Ok(_dropShipmentService.GeneratePOFromSales(req));
        }

        [HttpPost("CreateBackorderDropShip/{salesId}")]
        [DisplayName("Create Backorder Drop-Ship")]
        [PermissionKey("Vendor.DropShipment.Create")]
        public IActionResult CreateBackorderDropShip(int salesId)
        {
            return Ok(_dropShipmentService.CreateBackorderDropShip(salesId));
        }


        [HttpPost("UpdateShipQty/{purchaseId}")]
        [DisplayName("Update Ship Qty")]
        [PermissionKey("Vendor.DropShipment.UpdateShipQty")]
        public IActionResult UpdateShipQty(int purchaseId)
        {
            _dropShipmentService.UpdateShipQty(purchaseId);
            return Ok();
        }


        [HttpPost("UpdateReceiptQty/{purchaseId}")]
        [DisplayName("Update Receipt Qty")]
        [PermissionKey("Vendor.DropShipment.UpdateShipQty")]
        public IActionResult UpdateReceiptQty(int purchaseId, [FromBody] DropShipmentUpdateReceiptQtyReq req)
        {
            _dropShipmentService.UpdateReceiptQty(purchaseId, req);
            return Ok();
        }


        [HttpPost("ConvertPOToBill/{purchaseId}")]
        [DisplayName("Convert PO to Bill")]
        [PermissionKey("Vendor.DropShipment.ConvertToBill")]
        public IActionResult ConvertPOToBill(int purchaseId)
        {
            _dropShipmentService.ConvertPOToBill(purchaseId);
            return Ok();
        }


        [HttpPost("ReverseBill/{salesId}")]
        [DisplayName("Reverse Drop Ship Bill")]
        [PermissionKey("Vendor.DropShipment.ReverseBill")]
        public IActionResult ReverseBill(int salesId)
        {
            _dropShipmentService.ReverseBill(salesId);
            return Ok();
        }

        #endregion
    }
}
