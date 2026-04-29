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
    [Display(Name = "Inventory Adjustment Management", GroupName = "Product")]
    public class InventoryAdjsController : BaseController
    {
        #region --- Member(s) ---

        private readonly IInventoryAdjService _inventoryAdjService;

        #endregion

        #region --- Constructor(s) ---

        public InventoryAdjsController(IInventoryAdjService inventoryAdjService)
        {
            _inventoryAdjService = inventoryAdjService;
        }

        #endregion

        #region --- Method(s) ---

        [HttpGet]
        [DisplayName("List Adjustments")]
        [PermissionKey("Product.InventoryAdj.List")]
        public IActionResult List([FromQuery] InventoryAdjListReq inventoryAdjListReq)
        {
            return Ok(_inventoryAdjService.GetPagedList(inventoryAdjListReq));
        }


        [HttpGet("{id}")]
        public IActionResult GetById(int id)
        {
            var inventoryAdj = _inventoryAdjService.GetById(id);

            if (inventoryAdj == null)
                return NotFound($"InventoryAdj with ID {id} not found.");

            return Ok(inventoryAdj);
        }


        [HttpPost]
        [DisplayName("Create/Update Adjustment")]
        [PermissionKey("Product.InventoryAdj.Save")]
        public IActionResult Save([FromBody] InventoryAdj inventoryAdj)
        {
            return Ok(_inventoryAdjService.Save(inventoryAdj));
        }


        [HttpPost("Inject/{adjId}")]
        public IActionResult Inject(int adjId)
        {
            _inventoryAdjService.Inject(adjId);

            return Ok();
        }


        [HttpDelete("{adjId}")]
        [DisplayName("Delete Adjustment")]
        [PermissionKey("Product.InventoryAdj.Delete")]
        public IActionResult Delete(int adjId)
        {
            _inventoryAdjService.Delete(adjId);

            return Ok();
        }


        [HttpDelete("DeleteDetail/{adjDetailId}")]
        [DisplayName("Delete Detail")]
        [PermissionKey("Product.InventoryAdj.DeleteDetail")]
        public IActionResult DeleteDetail(int adjDetailId)
        {
            _inventoryAdjService.DeleteDetail(adjDetailId);

            return Ok();
        }


        [HttpPost("UpdateNotes")]
        public IActionResult UpdateNotes([FromBody] InventoryAdj inventoryAdj)
        {
            _inventoryAdjService.UpdateNotes(inventoryAdj);

            return Ok();
        }


        [HttpPost("UpdateDetailNotes")]
        public IActionResult UpdateDetailNotes([FromBody] InventoryAdjList inventoryAdjList)
        {
            _inventoryAdjService.UpdateDetailNotes(inventoryAdjList);

            return Ok();
        }


        [HttpPost("QtyAdj")]
        [DisplayName("Qty Adjustment")]
        [PermissionKey("Product.InventoryAdj.QtyAdj")]
        public IActionResult QtyAdj([FromBody] QtyAdjReq adjReq)
        {
            return Ok(_inventoryAdjService.QtyAdj(adjReq));
        }


        [HttpGet("GetClosingQty/{itemId}")]
        public IActionResult GetClosingQty(int itemId)
        {
            return Ok(_inventoryAdjService.GetClosingQty(itemId));
        }

        #endregion
    }
}
