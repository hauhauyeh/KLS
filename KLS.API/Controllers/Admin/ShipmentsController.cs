using KLS.API.Helpers;
using KLS.Contract.Services;
using KLS.Models;
using KLS.Services;
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel;
using System.ComponentModel.DataAnnotations;

namespace KLS.API.Controllers.Admin
{
    [AuthorizeAdmin]
    [Route("api/admin/[controller]")]
    [Display(Name = "Shipments Management", GroupName = "Vendor")]
    public class ShipmentsController : BaseController
    {
        #region --- Member(s) ---

        private readonly IShipmentService _shipmentService;

        #endregion

        #region --- Constructor(s) ---

        public ShipmentsController(IShipmentService shipmentService)
        {
            _shipmentService = shipmentService;
        }

        #endregion

        #region --- Method(s) ---

        [HttpGet]
        [DisplayName("List Shipments")]
        public IActionResult List([FromQuery] ShipmentListReq shipmentListReq)
        {
            return Ok(_shipmentService.GetPagedList(shipmentListReq));
        }


        [HttpGet("Open")]
        public IActionResult Open()
        {
            return Ok(_shipmentService.GetOpenShipments());
        }


        [HttpGet("{shipmentId}")]
        public IActionResult GetById(int shipmentId)
        {
            return Ok(_shipmentService.GetById(shipmentId));
        }


        [HttpPost]
        [DisplayName("Create Shipment")]
        public IActionResult Create([FromBody] Shipment shipment)
        {
            if (_shipmentService.Exists(shipment))
                return Conflict("Shipment already exists");

            return Ok(_shipmentService.Create(shipment));
        }


        [HttpPut]
        [DisplayName("Update Shipment")]
        public IActionResult Update([FromBody] Shipment shipment)
        {
            if (_shipmentService.Exists(shipment))
                return Conflict("Shipment already exists");

            return Ok(_shipmentService.Update(shipment));
        }


        [HttpPut("UpdateNotes")]
        public IActionResult UpdateNotes([FromBody] Shipment shipment)
        {
            _shipmentService.UpdateNotes(shipment);

            return Ok();
        }


        [HttpDelete("{shipmentId}")]
        [DisplayName("Delete Shipment")]
        public IActionResult Delete(int shipmentId)
        {
            _shipmentService.Delete(shipmentId);

            return Ok();
        }


        [HttpPost("UnAllocation/{shipmentPurchaseId}")]
        [DisplayName("UnAllocation Shipment")]
        public IActionResult UnAllocation(int shipmentPurchaseId)
        {
            _shipmentService.UnAllocation(shipmentPurchaseId);

            return Ok();
        }

        #endregion
    }
}
