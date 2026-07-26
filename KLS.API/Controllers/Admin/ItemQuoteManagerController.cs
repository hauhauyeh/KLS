using KLS.API.Helpers;
using KLS.Contract.Services;
using KLS.Models;
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel.DataAnnotations;

namespace KLS.API.Controllers.Admin
{
    [AuthorizeAdmin]
    [Route("api/admin/[controller]")]
    [Display(Name = "ItemQuote Manager", GroupName = "Customer")]
    public class ItemQuoteManagerController : BaseController
    {
        private readonly IItemQuoteManagerService _itemQuoteManagerService;

        public ItemQuoteManagerController(IItemQuoteManagerService itemQuoteManagerService)
        {
            _itemQuoteManagerService = itemQuoteManagerService;
        }

        [HttpGet("{payeeId}/rows")]
        [PermissionKey("Customer.Customer.List")]
        public IActionResult Rows(int payeeId)
        {
            return Ok(_itemQuoteManagerService.GetRows(payeeId));
        }

        [HttpPost("{payeeId}/inject")]
        [PermissionKey("Customer.Customer.Update")]
        public IActionResult Inject(int payeeId)
        {
            return Ok(_itemQuoteManagerService.Inject(payeeId));
        }

        [HttpPost("{payeeId}/save")]
        [PermissionKey("Customer.Customer.Update")]
        public IActionResult Save(int payeeId)
        {
            return Ok(_itemQuoteManagerService.Save(payeeId));
        }

        [HttpPost("{payeeId}/clear")]
        [PermissionKey("Customer.Customer.Update")]
        public IActionResult Clear(int payeeId)
        {
            return Ok(_itemQuoteManagerService.Clear(payeeId));
        }

        [HttpPost("{payeeId}/add-item")]
        [PermissionKey("Customer.Customer.Update")]
        public IActionResult AddItem(int payeeId, [FromBody] ItemQuoteManagerAddItemReq req)
        {
            return Ok(_itemQuoteManagerService.AddItem(payeeId, req));
        }

        [HttpPost("{payeeId}/override")]
        [PermissionKey("Customer.Customer.Update")]
        public IActionResult Override(int payeeId, [FromBody] ItemQuoteManagerOverrideReq req)
        {
            return Ok(_itemQuoteManagerService.Override(payeeId, req));
        }

        [HttpPut("{payeeId}/draft-row/{tempQuoteId}")]
        [PermissionKey("Customer.Customer.Update")]
        public IActionResult UpdateDraftRow(int payeeId, int tempQuoteId, [FromBody] ItemQuoteManagerUpdateDraftRowReq req)
        {
            return Ok(_itemQuoteManagerService.UpdateDraftRow(payeeId, tempQuoteId, req));
        }

        [HttpDelete("{payeeId}/draft-row/{tempQuoteId}")]
        [PermissionKey("Customer.Customer.Update")]
        public IActionResult DeleteDraftRow(int payeeId, int tempQuoteId)
        {
            return Ok(_itemQuoteManagerService.DeleteDraftRow(payeeId, tempQuoteId));
        }
    }
}
