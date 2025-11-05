using KLS.API.Helpers;
using KLS.Models;
using KLS.Services.Interfaces;
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel.DataAnnotations;

namespace KLS.API.Controllers.Admin
{
    [AuthorizeAdmin]
    [Route("api/admin/[controller]")]
    [Display(Name = "Temp Purchase Management", GroupName = "Admin")]
    public class TempPurchasesController : BaseController
    {
        #region --- Member(s) ---

        private readonly ITempPurchaseService _tempPurchaseService;

        #endregion

        #region --- Constructor(s) ---

        public TempPurchasesController(ITempPurchaseService tempPurchaseService)
        {
            _tempPurchaseService = tempPurchaseService;
        }

        #endregion

        #region --- Method(s) ---

        [HttpGet]
        public IActionResult List([FromQuery] TempPurchaseReq tempReq)
        {
            return Ok(_tempPurchaseService.GetTempPurchaseItems(tempReq));
        }


        [HttpPost]
        public IActionResult Create([FromBody] TempPurchaseItem tempPurchase)
        {
            return Ok(_tempPurchaseService.CreateTempPurchase(tempPurchase));
        }


        [HttpPut]
        public IActionResult Update([FromBody] TempPurchaseItem tempPurchase)
        {
            return Ok(_tempPurchaseService.UpdateTempPurchase(tempPurchase));
        }


        [HttpDelete("{tempId}")]
        public IActionResult Delete(int tempId)
        {
            _tempPurchaseService.DeleteTempPurchase(tempId);
            return Ok();
        }


        [HttpPost("Clear")]
        public IActionResult Clear([FromBody] TempPurchaseReq tempReq)
        {
            _tempPurchaseService.ClearTempPurchase(tempReq);
            return Ok();
        }

        #endregion
    }
}
