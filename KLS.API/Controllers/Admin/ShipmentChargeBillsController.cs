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
    [Display(Name = "Shipment Charge Bills Management", GroupName = "Vendor")]
    public class ShipmentChargeBillsController : BaseController
    {
        private readonly IShipmentChargeBillService _shipmentChargeBillService;

        public ShipmentChargeBillsController(IShipmentChargeBillService shipmentChargeBillService)
        {
            _shipmentChargeBillService = shipmentChargeBillService;
        }

        [HttpGet("ByShipment/{shipmentId}")]
        [DisplayName("List Shipment Charge Bills")]
        [PermissionKey("Vendor.Shipment.List")]
        public IActionResult ByShipment(int shipmentId)
        {
            return Ok(_shipmentChargeBillService.GetByShipmentId(shipmentId));
        }

        [HttpGet("{shipmentChargeBillId}")]
        [DisplayName("Get Shipment Charge Bill")]
        [PermissionKey("Vendor.Shipment.List")]
        public IActionResult GetById(int shipmentChargeBillId)
        {
            var bill = _shipmentChargeBillService.GetById(shipmentChargeBillId);
            if (bill == null)
                return NotFound("Charge bill not found.");

            return Ok(bill);
        }

        [HttpPost]
        [DisplayName("Save Shipment Charge Bill")]
        [PermissionKey("Vendor.Shipment.Update")]
        public IActionResult Save([FromBody] ShipmentChargeBillSaveReq req)
        {
            return Ok(_shipmentChargeBillService.Save(req));
        }

        [HttpDelete("{shipmentChargeBillId}")]
        [DisplayName("Delete Shipment Charge Bill")]
        [PermissionKey("Vendor.Shipment.Update")]
        public IActionResult Delete(int shipmentChargeBillId)
        {
            _shipmentChargeBillService.Delete(shipmentChargeBillId);
            return Ok();
        }

    }
}
