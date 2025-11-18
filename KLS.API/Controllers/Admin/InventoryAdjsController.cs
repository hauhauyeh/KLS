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
    [Display(Name = "InventoryAdj Management", GroupName = "Admin")]
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
            return Ok(_inventoryAdjService.GetinventoryAdj(inventoryAdjListReq));
        }


        [HttpPost("UpdateNotes")]
        public IActionResult UpdateNotes([FromBody] InventoryAdj inventoryAdj)
        {
            _inventoryAdjService.UpdateNotes(inventoryAdj);

            return Ok();
        }


        [HttpPost("UpdateDetailNotes")]
        public IActionResult UpdateDetailNotes([FromBody] InventoryAdj inventoryAdj)
        {
            _inventoryAdjService.UpdateDetailNotes(inventoryAdj);

            return Ok();
        }

        #endregion
    }
}
