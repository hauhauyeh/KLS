using KLS.API.Helpers;
using KLS.Models;
using KLS.Services.Interfaces;
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
        [DisplayName("List InventoryAdj")]
        public IActionResult List([FromQuery] InventoryAdjListReq inventoryAdjListReq)
        {
            return Ok(_inventoryAdjService.GetAllInventoryAdj(inventoryAdjListReq));
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
        [DisplayName("Save Adjustment")]
        public IActionResult Save([FromBody] InventoryAdj inventoryAdj)
        {
            return Ok(_inventoryAdjService.SaveInventoryAdj(inventoryAdj));
        }


        [HttpPost("Inject/{adjId}")]
        public IActionResult Inject(int adjId)
        {
            _inventoryAdjService.InjectInventoryAdj(adjId);

            return Ok();
        }


        [HttpDelete("{adjId}")]
        [DisplayName("Delete Adjustment")]
        public IActionResult Delete(int adjId)
        {
            _inventoryAdjService.DeleteInventoryAdj(adjId);

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

        #endregion
    }
}
