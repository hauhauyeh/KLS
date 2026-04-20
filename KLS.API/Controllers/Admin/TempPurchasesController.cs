using KLS.API.Helpers;
using KLS.Common;
using KLS.Contract.Services;
using KLS.Models;
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
            return Ok(_tempPurchaseService.GetList(tempReq));
        }


        [HttpPost]
        public IActionResult Create([FromBody] TempPurchaseItem tempPurchase)
        {
            return Ok(_tempPurchaseService.Create(tempPurchase, EnumHelper.PurchaseDocType.Bill));
        }


        [HttpPut]
        public IActionResult Update([FromBody] TempPurchaseItem tempPurchase)
        {
            return Ok(_tempPurchaseService.Update(tempPurchase, EnumHelper.PurchaseDocType.Bill));
        }


        [HttpPut("UpdateUnit")]
        public IActionResult UpdateUnit([FromBody] TempPurchaseItem tempPurchase)
        {
            return Ok(_tempPurchaseService.UpdateUnit(tempPurchase));
        }


        [HttpPost("Reorder")]
        public IActionResult Reorder([FromBody] TempPurchaseReorderReq reorderReq)
        {
            _tempPurchaseService.Reorder(reorderReq);
            return Ok();
        }


        [HttpDelete("{tempId}")]
        public IActionResult Delete(int tempId)
        {
            _tempPurchaseService.Delete(tempId);
            return Ok();
        }


        [HttpPost("Clear")]
        public IActionResult Clear([FromBody] TempPurchaseReq tempReq)
        {
            _tempPurchaseService.Clear(tempReq);
            return Ok();
        }


        [HttpPost("CreatePOItem")]
        public IActionResult CreatePOItem([FromBody] TempPurchaseItem tempPurchase)
        {
            return Ok(_tempPurchaseService.Create(tempPurchase, EnumHelper.PurchaseDocType.PO));
        }


        [HttpPut("UpdatePOItem")]
        public IActionResult UpdatePOItem([FromBody] TempPurchaseItem tempPurchase)
        {
            return Ok(_tempPurchaseService.Update(tempPurchase, EnumHelper.PurchaseDocType.PO));
        }

        #endregion
    }
}
