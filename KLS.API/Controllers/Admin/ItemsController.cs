using KLS.API.Helpers;
using KLS.Contract.Services;
using KLS.Models;
using KLS.Services;
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel;
using System.ComponentModel.DataAnnotations;

namespace KLS.API.Controllers.Admin
{
    [AuthorizeAdmin]
    [Route("api/admin/[controller]")]
    [Display(Name = "Product Management", GroupName = "Product")]
    public class ItemsController : BaseController
    {
        #region --- Member(s) ---

        private readonly IItemService _itemService;
        private readonly IItemQuoteService _itemQuoteService;

        #endregion

        #region --- Constructor(s) ---

        public ItemsController(IItemService itemService, IItemQuoteService itemQuoteService)
        {
            _itemService = itemService;
            _itemQuoteService = itemQuoteService;
        }

        #endregion

        #region --- Method(s) ---

        [HttpGet]
        [DisplayName("List Products")]
        public IActionResult List([FromQuery] ItemListReq itemListReq)
        {
            return Ok(_itemService.GetPagedList(itemListReq));
        }

        [HttpGet("ActiveItems")]
        public IActionResult ActiveItems()
        {
            return Ok(_itemService.ActiveItems());
        }


        [HttpGet("{itemId}")]
        public IActionResult GetById(int itemId)
        {
            var item = _itemService.GetById(itemId);

            if (item == null)
                return NotFound($"Product not found.");

            return Ok(item);
        }


        [HttpGet("Search")]
        public IActionResult Search([FromQuery] ItemSearchReq searchReq)
        {
            return Ok(_itemService.Search(searchReq));
        }


        [HttpDelete("{itemId}")]
        [DisplayName("Delete Product")]
        public IActionResult Delete(int itemId)
        {
            _itemService.Delete(itemId);
            return Ok();
        }


        [HttpPut("Inactive/{itemId}")]
        public IActionResult Inactive(int itemId)
        {
            _itemService.Inactive(itemId);
            return Ok();
        }


        [HttpPost]
        [DisplayName("Create/Update Product")]
        public IActionResult Save([FromBody] Item item)
        {
            if (_itemService.ItemCodeExists(item))
                return Conflict("Code already exists");

            if (_itemService.ItemNameExists(item))
                return Conflict("Name already exists");

            return Ok(_itemService.Save(item));
        }


        [HttpGet("CalcUnit")]
        public IActionResult CalcUnit([FromQuery] ItemPackingReq packingReq)
        {
            return Ok(_itemService.GetCalcUnit(packingReq));
        }


        [HttpGet("CalcRetailPriceProfit")]
        public IActionResult CalcRetailPriceProfit([FromQuery] ItemCalcRetail calcRetail)
        {
            return Ok(_itemService.CalcRetailPriceProfit(calcRetail));
        }


        [HttpPut("UpdateBaseP1")]
        [DisplayName("Edit P1")]
        public IActionResult UpdateBaseP1([FromBody] ItemUpdateReq updateReq)
        {
            _itemService.UpdateBaseP1(updateReq);
            return Ok();
        }


        [HttpGet("GetTargetPrice/{itemId}")]
        public IActionResult GetTargetPrice(int itemId, [FromQuery] string? filterby)
        {
            return Ok(_itemQuoteService.GetTargetrPrice(itemId, filterby));
        }


        [HttpGet("GetDefaultFreight/{itemId}")]
        public IActionResult GetDefaultFreight(int itemId)
        {
            return Ok(_itemService.GetDefaultFreight(itemId));
        }


        [HttpPut("SaveFreight")]
        public IActionResult SaveFreight([FromBody] ItemDefaultFreight defaultFreight)
        {
            _itemService.SaveFreight(defaultFreight);
            return Ok();
        }

        #endregion
    }
}
