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
    [Display(Name = "Shared Shipment Charge Bills", GroupName = "Vendor")]
    public class SharedShipmentChargeBillsController : BaseController
    {
        private readonly ISharedShipmentChargeBillService _sharedShipmentChargeBillService;

        public SharedShipmentChargeBillsController(ISharedShipmentChargeBillService sharedShipmentChargeBillService)
        {
            _sharedShipmentChargeBillService = sharedShipmentChargeBillService;
        }

        [HttpGet]
        [DisplayName("List Shared Shipment Charge Bills")]
        [PermissionKey("Vendor.Shipment.Update")]
        public IActionResult GetList()
        {
            return Ok(_sharedShipmentChargeBillService.GetList());
        }

        [HttpGet("{sharedShipmentChargeBillId}")]
        [DisplayName("Get Shared Shipment Charge Bill")]
        [PermissionKey("Vendor.Shipment.Update")]
        public IActionResult GetById(int sharedShipmentChargeBillId)
        {
            var bill = _sharedShipmentChargeBillService.GetById(sharedShipmentChargeBillId);
            if (bill == null)
                return NotFound("Shared charge bill not found.");

            return Ok(bill);
        }

        [HttpPost("Draft")]
        [DisplayName("Save Shared Shipment Charge Bill Draft")]
        [PermissionKey("Vendor.Shipment.Update")]
        public IActionResult SaveDraft([FromBody] SharedShipmentChargeBillSaveReq req)
        {
            return Ok(_sharedShipmentChargeBillService.SaveDraft(req));
        }

        [HttpDelete("Draft/{sharedShipmentChargeBillId}")]
        [DisplayName("Delete Shared Shipment Charge Bill Draft")]
        [PermissionKey("Vendor.Shipment.Update")]
        public IActionResult DeleteDraft(int sharedShipmentChargeBillId)
        {
            _sharedShipmentChargeBillService.DeleteDraft(sharedShipmentChargeBillId);
            return Ok();
        }

        [HttpPost("{sharedShipmentChargeBillId}/Apply")]
        [DisplayName("Apply Shared Shipment Charge Bill")]
        [PermissionKey("Vendor.Shipment.GenerateBill")]
        public IActionResult Apply(int sharedShipmentChargeBillId)
        {
            return Ok(_sharedShipmentChargeBillService.Apply(sharedShipmentChargeBillId));
        }

        [HttpPost("{sharedShipmentChargeBillId}/Void")]
        [DisplayName("Void Shared Shipment Charge Bill")]
        [PermissionKey("Vendor.Shipment.GenerateBill")]
        public IActionResult Void(int sharedShipmentChargeBillId)
        {
            return Ok(_sharedShipmentChargeBillService.Void(sharedShipmentChargeBillId));
        }
    }
}
