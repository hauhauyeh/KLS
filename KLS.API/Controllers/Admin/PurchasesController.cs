using KLS.API.Helpers;
using KLS.Models;
using KLS.Services;
using KLS.Services.Interfaces;
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel;
using System.ComponentModel.DataAnnotations;

namespace KLS.API.Controllers.Admin
{
    [AuthorizeAdmin]
    [Route("api/admin/[controller]")]
    [Display(Name = "Purchase Management", GroupName = "Admin")]
    public class PurchasesController : BaseController
    {
        #region --- Member(s) ---

        private readonly IPurchaseService _purchaseService;

        #endregion

        #region --- Constructor(s) ---

        public PurchasesController(IPurchaseService purchaseService)
        {
            _purchaseService = purchaseService;
        }

        #endregion

        #region --- Method(s) ---

        [HttpGet]
        [DisplayName("Bill Manager")]
        public IActionResult List([FromQuery] PurchaseListReq purchaseListReq)
        {
            return Ok(_purchaseService.GetAllPurchase(purchaseListReq));
        }


        [HttpPut("UpdateNotes")]
        public IActionResult UpdateNotes([FromBody] PurchaseUpdateReq updateReq)
        {
            _purchaseService.UpdateNotes(updateReq.PurchaseId, updateReq.Notes);

            return Ok();
        }


        [HttpPut("UpdateDocNumber")]
        public IActionResult UpdateDocNumber([FromBody] PurchaseUpdateReq updateReq)
        {
            _purchaseService.UpdateDocNumber(updateReq.PurchaseId, updateReq.VendorDocNumber);

            return Ok();
        }


        [HttpDelete("{purchaseId}")]
        [DisplayName("Delete Bill")]
        public IActionResult Delete(int purchaseId)
        {
            _purchaseService.DeletePurchase(purchaseId);
            return Ok();
        }

        #endregion
    }
}
