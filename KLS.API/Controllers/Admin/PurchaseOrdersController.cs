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
    [Display(Name = "PurchaseOrder Management", GroupName = "Admin")]
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
        [DisplayName("List PurchaseOrders")]
        public IActionResult List([FromQuery] PurchaseOrderReq purchaseOrderReq)
        {
            return Ok(_purchaseOrderService.GetAllPurchaseOrders(purchaseOrderReq));
        }


        [HttpGet("{poId}")]
        public IActionResult GetById(int poId)
        {
            var purchaseOrder = _purchaseOrderService.GetById(poId);

            if (purchaseOrder == null)
                return NotFound($"PurchaseOrder with Id {poId} not found.");

            return Ok(purchaseOrder);
        }


        [HttpPost("UpdateNotes")]
        public IActionResult UpdateNotes([FromBody] PurchaseOrder purchaseOrder)
        {
            _purchaseOrderService.UpdateNotes(purchaseOrder.POId, purchaseOrder.Notes);

            return Ok();
        }


        [HttpPost("UpdateContainerNumber")]
        public IActionResult UpdateContainerNumber([FromBody] PurchaseOrder purchaseOrder)
        {
            _purchaseOrderService.UpdateContainerNumber(purchaseOrder);

            return Ok();
        }


        [HttpPost("UpdateVendorDocNumber")]
        public IActionResult UpdateVendorDocNumber([FromBody] PurchaseOrder purchaseOrder)
        {
            _purchaseOrderService.UpdateVendorDocNumber(purchaseOrder);

            return Ok();
        }


        [HttpPost("Inject")]
        public IActionResult Inject([FromBody] PurchaseOrderInjectReq injectReq)
        {
            _purchaseOrderService.InjectPurchaseOrder(injectReq);
            return Ok();
        }


        [HttpPost("Checkout")]
        [DisplayName("Checkout PO")]
        public IActionResult Checkout([FromBody] PurchaseOrderCheckoutReq checkoutReq)
        {
            return Ok(_purchaseOrderService.Checkout(checkoutReq));
        }


        [HttpDelete("{poId}")]
        [DisplayName("Delete PO")]
        public IActionResult Delete(int poId)
        {
            _purchaseOrderService.DeletePurchaseOrder(poId);

            return Ok();
        }


        [HttpPost("SaveAdvancePayment")]
        [DisplayName("Save Advance Payment")]
        public IActionResult SaveAdvancePayment([FromBody] POAdvancePaymentReq advancePaymentReq)
        {
            _purchaseOrderService.SaveAdvancePayment(advancePaymentReq);
            return Ok();
        }


        [HttpDelete("DeleteAdvancePayment/{poId}")]
        [DisplayName("Delete Advance Payment")]
        public IActionResult DeleteAdvancePayment(int poId)
        {
            _purchaseOrderService.DeleteAdvancePayment(poId);
            return Ok();
        }


        [HttpGet("GetPODetail/{poId}")]
        public IActionResult GetPODetail(int poId)
        {
            return Ok(_purchaseOrderService.GetPODetail(poId));
        }


        [HttpPost("CopyToBill")]
        public IActionResult CopyToBill([FromBody] POCopyToBillReq copyToBillReq)
        {
            return Ok(_purchaseOrderService.CopyToBill(copyToBillReq));
        }

        #endregion
    }
}
