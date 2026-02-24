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
    [Display(Name = "PO Management", GroupName = "Vendor")]
    public class PurchaseOrdersController : BaseController
    {
        #region --- Member(s) ---

        private readonly IPurchaseOrderService _purchaseOrderService;

        #endregion

        #region --- Constructor(s) ---

        public PurchaseOrdersController(IPurchaseOrderService purchaseOrderService)
        {
            _purchaseOrderService = purchaseOrderService;
        }

        #endregion

        #region --- Method(s) ---

        [HttpGet]
        [DisplayName("List PO")]
        public IActionResult List([FromQuery] PurchaseOrderReq purchaseOrderReq)
        {
            return Ok(_purchaseOrderService.GetPagedList(purchaseOrderReq));
        }


        [HttpPost("Checkout")]
        [DisplayName("Create/Update PO")]
        public IActionResult Checkout([FromBody] PurchaseOrderCheckoutReq checkoutReq)
        {
            return Ok(_purchaseOrderService.Checkout(checkoutReq));
        }


        [HttpDelete("{purchaseId}")]
        [DisplayName("Delete PO")]
        public IActionResult Delete(int purchaseId)
        {
            _purchaseOrderService.Delete(purchaseId);

            return Ok();
        }


        [HttpGet("GetPODetail/{purchaseId}")]
        public IActionResult GetPODetail(int purchaseId)
        {
            return Ok(_purchaseOrderService.GetPODetail(purchaseId));
        }


        [HttpPost("CopyToBill")]
        public IActionResult CopyToBill([FromBody] POCopyToBillReq copyToBillReq)
        {
            return Ok(_purchaseOrderService.CopyToBill(copyToBillReq));
        }


        [HttpGet("PrintPO/{purchaseId}")]
        public IActionResult PrintPO(int purchaseId)
        {
            var poFilePath = _purchaseOrderService.PrintPO(purchaseId);

            if (!System.IO.File.Exists(poFilePath))
                return NotFound("File not found.");

            var fileStream = new FileStream(poFilePath, FileMode.Open, FileAccess.Read, FileShare.Read);
            return File(fileStream, "application/pdf");
        }


        [HttpPut("UpdateToBillStage/{purchaseId}")]
        public IActionResult UpdateToBillStage(int purchaseId)
        {
            return Ok(_purchaseOrderService.UpdateToBillStage(purchaseId));
        }

        #endregion
    }
}
