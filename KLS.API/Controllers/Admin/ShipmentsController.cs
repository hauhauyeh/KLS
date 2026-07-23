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
        [PermissionKey("Vendor.Shipment.List")]
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
        [PermissionKey("Vendor.Shipment.Create")]
        public IActionResult Create([FromBody] Shipment shipment)
        {
            if (_shipmentService.Exists(shipment))
                return Conflict("Shipment already exists");

            return Ok(_shipmentService.Create(shipment));
        }


        [HttpPut]
        [DisplayName("Update Shipment")]
        [PermissionKey("Vendor.Shipment.Update")]
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
        [PermissionKey("Vendor.Shipment.Delete")]
        public IActionResult Delete(int shipmentId)
        {
            _shipmentService.Delete(shipmentId);

            return Ok();
        }


        [HttpPut("Reopen/{shipmentId}")]
        [DisplayName("Reopen Shipment")]
        [PermissionKey("Vendor.Shipment.Reopen")]
        public IActionResult Reopen(int shipmentId)
        {
            return Ok(_shipmentService.Reopen(shipmentId));
        }


        [HttpPost("GenerateBill/{shipmentId}")]
        [DisplayName("Generate Bill")]
        [PermissionKey("Vendor.Shipment.GenerateBill")]
        public IActionResult GenerateBill(int shipmentId)
        {
            return Ok(_shipmentService.GenerateBill(shipmentId));
        }


        [HttpPost("UnAllocation/{shipmentPurchaseId}")]
        [DisplayName("UnAllocation Shipment")]
        [PermissionKey("Vendor.Shipment.UnAllocation")]
        public IActionResult UnAllocation(int shipmentPurchaseId)
        {
            _shipmentService.UnAllocation(shipmentPurchaseId);

            return Ok();
        }


        [HttpGet("AssignedPurchases/{shipmentId}")]
        public IActionResult AssignedPurchases(int shipmentId)
        {
            return Ok(_shipmentService.AssignedPurchases(shipmentId));
        }

        [HttpGet("{shipmentId}/BillBasisUsability")]
        public IActionResult BillBasisUsability(int shipmentId)
        {
            return Ok(_shipmentService.BillBasisUsability(shipmentId));
        }


        // Multi-Bill Assign: bills selectable in the Add-Bills picker for this shipment.
        [HttpGet("{shipmentId}/EligibleBills")]
        public IActionResult EligibleBills(int shipmentId, [FromQuery] string? search)
        {
            return Ok(_shipmentService.EligibleBills(shipmentId, search));
        }


        // Multi-Bill Assign: batch-assign the selected bills to this shipment.
        [HttpPost("{shipmentId}/AssignBills")]
        [DisplayName("Assign Bills To Shipment")]
        [PermissionKey("Vendor.Shipment.AssignBills")]
        public IActionResult AssignBills(int shipmentId, [FromBody] AssignBillsReq req)
        {
            return Ok(_shipmentService.AssignBills(shipmentId, req));
        }


        [HttpGet("ValidateAllocation/{purchaseId}")]
        public IActionResult ValidateAllocation(int purchaseId)
        {
            return Ok(_shipmentService.ValidateAllocation(purchaseId));
        }


        [HttpGet("ValidateAllocationDetail/{purchaseId}/{method}")]
        public IActionResult ValidateAllocationDetail(int purchaseId, string method)
        {
            return Ok(_shipmentService.ValidateAllocationDetail(purchaseId, method));
        }


        // 2026-06-29: shipment-scoped validation (Plan 1) — coverage over all bills in the shipment
        // (the allocation guard's scope), so the UI can warn truthfully at assignment time.
        [HttpGet("ValidateAllocationByShipment/{shipmentId}")]
        public IActionResult ValidateAllocationByShipment(int shipmentId)
        {
            return Ok(_shipmentService.ValidateAllocationByShipment(shipmentId));
        }


        [HttpGet("ValidateAllocationByShipmentDetail/{shipmentId}/{method}")]
        public IActionResult ValidateAllocationByShipmentDetail(int shipmentId, string method)
        {
            return Ok(_shipmentService.ValidateAllocationByShipmentDetail(shipmentId, method));
        }


        [HttpPost("CleanupReallocation/{shipmentId}")]
        [DisplayName("Cleanup Shipment Reallocation")]
        [PermissionKey("Vendor.Shipment.Update")]
        public IActionResult CleanupReallocation(int shipmentId)
        {
            return Ok(_shipmentService.CleanupReallocationForShipment(shipmentId));
        }


        [HttpPost("SplitCharge")]
        [DisplayName("Split Charge To Bills")]
        [PermissionKey("Vendor.Shipment.SplitCharge")]
        public IActionResult SplitCharge([FromBody] ChargeSplitReq req)
        {
            return Ok(_shipmentService.SplitCharge(req));
        }

        #endregion
    }
}
