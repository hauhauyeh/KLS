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
    [Display(Name = "ItemHistory Management", GroupName = "Product")]
    public class ItemHistoriesController : BaseController
    {
        #region --- Member(s) ---

        private readonly IItemHistoryService _itemHistoryService;

        #endregion

        #region --- Constructor(s) ---

        public ItemHistoriesController(IItemHistoryService itemHistoryService)
        {
            _itemHistoryService = itemHistoryService;
        }

        #endregion

        #region --- Method(s) ---

        [HttpGet("Sales")]
        [DisplayName("Sales History")]
        public IActionResult Sales([FromQuery] ItemHistoryReq itemHistoryReq)
        {
            return Ok(_itemHistoryService.GetSalesHistory(itemHistoryReq));
        }


        [HttpGet("Purchase")]
        [DisplayName("Cost History")]
        public IActionResult Purchase([FromQuery] ItemHistoryReq itemHistoryReq)
        {
            return Ok(_itemHistoryService.GetPurchaseHistory(itemHistoryReq));
        }


        [HttpGet("Inventory")]
        [DisplayName("Inventory History")]
        public IActionResult Inventory([FromQuery] ItemHistoryReq itemHistoryReq)
        {
            return Ok(_itemHistoryService.GetInventoryHistory(itemHistoryReq));
        }


        [HttpGet("SalesCost")]
        [DisplayName("Cost + Sales History")]
        public IActionResult SalesCost([FromQuery] ItemHistoryReq itemHistoryReq)
        {
            return Ok(new
            {
                Sales = _itemHistoryService.GetSalesHistory(itemHistoryReq),
                Purchase = _itemHistoryService.GetPurchaseHistory(itemHistoryReq).ToList().Take(5)
            });
        }

        #endregion
    }
}
