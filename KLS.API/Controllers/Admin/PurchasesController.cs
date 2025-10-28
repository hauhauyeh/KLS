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
        [DisplayName("List Purchase")]
        public IActionResult List([FromQuery] PurchaseListReq purchaseListReq)
        {
            return Ok(_purchaseService.GetAllPurchase(purchaseListReq));
        }


        [HttpPost("UpdateNotes")]
        public IActionResult UpdateNotes([FromBody] Purchase purchase)
        {
            _purchaseService.UpdateNotes(purchase);

            return Ok();
        }


        [HttpPost("UpdateVendorDocNumber")]
        public IActionResult UpdateVendorDocNumber([FromBody] Purchase purchase)
        {
            _purchaseService.UpdateVendorDocNumber(purchase);

            return Ok();
        }

        #endregion
    }
}
