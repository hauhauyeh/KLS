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
    [Display(Name = "Product History Management", GroupName = "Product")]
    public class ItemHistoriesController : BaseController
    {
        #region --- Member(s) ---

        private readonly IItemHistoryService _itemHistoryService;
        private readonly IInventoryAdjService _adjustmentService;

        #endregion

        #region --- Constructor(s) ---

        public ItemHistoriesController(IItemHistoryService itemHistoryService, IInventoryAdjService adjustmentService)
        {
            _itemHistoryService = itemHistoryService;
            _adjustmentService = adjustmentService;
        }

        #endregion

        #region --- Method(s) ---

        [HttpGet("Sales")]
        [DisplayName("View Order History")]
        public IActionResult Sales([FromQuery] ItemHistoryReq itemHistoryReq)
        {
            return Ok(_itemHistoryService.GetSalesHistory(itemHistoryReq));
        }


        [HttpGet("Purchase")]
        [DisplayName("View Cost History")]
        public IActionResult Purchase([FromQuery] ItemHistoryReq itemHistoryReq)
        {
            return Ok(_itemHistoryService.GetPurchaseHistory(itemHistoryReq));
        }


        [HttpGet("Inventory")]
        [DisplayName("View Inventory History")]
        public IActionResult Inventory([FromQuery] ItemHistoryReq itemHistoryReq)
        {
            return Ok(_itemHistoryService.GetInventoryHistory(itemHistoryReq));
        }


        [HttpGet("SalesCost")]
        [DisplayName("View Cost + Order History")]
        public IActionResult SalesCost([FromQuery] ItemHistoryReq itemHistoryReq)
        {
            return Ok(new
            {
                Sales = _itemHistoryService.GetSalesHistory(itemHistoryReq),
                Purchase = _itemHistoryService.GetPurchaseHistory(itemHistoryReq).ToList().Take(5)
            });
        }


        [HttpGet("Adjustment/{itemId}")]
        [DisplayName("View Adjustment History")]
        public IActionResult Adjustment(string itemId)
        {
            var adjustments = _adjustmentService.GetPagedList(new InventoryAdjListReq
            {
                Pagesize = 300,
                Search = itemId
            });
            return Ok(adjustments.RowData);
        }

        #endregion
    }
}
