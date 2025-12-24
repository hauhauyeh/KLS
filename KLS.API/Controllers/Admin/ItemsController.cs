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
    [Display(Name = "Item Management", GroupName = "Product")]
    public class ItemsController : BaseController
    {
        #region --- Member(s) ---

        private readonly IItemService _itemService;

        #endregion

        #region --- Constructor(s) ---

        public ItemsController(IItemService itemService)
        {
            _itemService = itemService;
        }

        #endregion

        #region --- Method(s) ---

        [HttpGet]
        [DisplayName("List Item")]
        public IActionResult List([FromQuery] ItemListReq itemListReq)
        {
            return Ok(_itemService.GetPagedList(itemListReq));
        }


        [HttpGet("{itemId}")]
        public IActionResult GetById(int itemId)
        {
            var item = _itemService.GetById(itemId);

            if (item == null)
                return NotFound($"Item not found.");

            return Ok(item);
        }


        [HttpGet("Search")]
        public IActionResult Search([FromQuery] ItemSearchReq searchReq)
        {
            return Ok(_itemService.Search(searchReq));
        }


        [HttpDelete("{itemId}")]
        [DisplayName("Delete Item")]
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
        [DisplayName("Save Item")]
        public IActionResult Save([FromBody] Item item)
        {
            if (_itemService.ItemCodeExists(item))
                return Conflict("ItemCode already exists");

            if (_itemService.ItemNameExists(item))
                return Conflict("ItemName already exists");

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


        //[HttpGet("DefaultUnits")]
        //public IActionResult DefaultUnits()
        //{
        //    return Ok(Enum.GetNames(typeof(EnumHelper.ItemDefaultUnit)).ToList());
        //}


        //[HttpPut("UpdateDefautCost")]
        //public IActionResult UpdateDefautCost([FromBody] ItemUpdateReq updateReq)
        //{
        //    _itemService.UpdateDefautCost(updateReq.ItemId, updateReq.DefaultCost);
        //    return Ok();
        //}


        //[HttpPut("UpdateP1")]
        //public IActionResult UpdateP1([FromBody] ItemUpdateReq updateReq)
        //{
        //    return Ok(_itemService.UpdateP1(updateReq.ItemId, updateReq.P1));
        //}


        //[HttpPut("UpdateRetailPrice")]
        //public IActionResult UpdateRetailPrice([FromBody] ItemUpdateReq updateReq)
        //{
        //    return Ok(_itemService.UpdateRetailPrice(updateReq.ItemId, updateReq.RetailPrice));
        //}


        //[HttpPut("UpdateRetailProfit")]
        //public IActionResult UpdateRetailProfit([FromBody] ItemUpdateReq updateReq)
        //{
        //    return Ok(_itemService.UpdateRetailProfit(updateReq.ItemId, updateReq.RetailProfitPercent));
        //}


        [HttpGet("EditP1")]
        [DisplayName("Edit P1")]
        public IActionResult EditP1()
        {
            return Ok();
        }

        #endregion
    }
}
