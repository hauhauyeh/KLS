using KLS.API.Helpers;
using KLS.Contract.Services;
using KLS.Models;
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel.DataAnnotations;

namespace KLS.API.Controllers.Admin
{
    [AuthorizeAdmin]
    [Route("api/admin/[controller]")]
    [Display(Name = "Temp Adjustment Management", GroupName = "Product")]
    public class TempInventoryAdjsController : BaseController
    {
        #region --- Member(s) ---

        private readonly ITempInventoryAdjService _tempInventoryAdjService;

        #endregion

        #region --- Constructor(s) ---

        public TempInventoryAdjsController(ITempInventoryAdjService tempInventoryAdjService)
        {
            _tempInventoryAdjService = tempInventoryAdjService;
        }

        #endregion

        #region --- Method(s) ---

        [HttpGet]
        public IActionResult List([FromQuery] TempInventoryReq tempReq)
        {
            return Ok(_tempInventoryAdjService.GetTempAdjItems(tempReq));
        }


        [HttpPost]
        public IActionResult Create([FromBody] TempInventoryItem tempItem)
        {
            return Ok(_tempInventoryAdjService.CreateTempItem(tempItem));
        }


        [HttpPut]
        public IActionResult Update([FromBody] TempInventoryAdj adjCart)
        {
            _tempInventoryAdjService.UpdateTempItem(adjCart);
            return Ok();
        }


        [HttpDelete("{tempAdjId}")]
        public IActionResult Delete(int tempAdjId)
        {
            _tempInventoryAdjService.DeleteTempItem(tempAdjId);
            return Ok();
        }


        [HttpPost("Clear")]
        public IActionResult Clear([FromBody] TempInventoryReq tempReq)
        {
            _tempInventoryAdjService.ClearTempItem(tempReq);
            return Ok();
        }

        #endregion
    }
}
