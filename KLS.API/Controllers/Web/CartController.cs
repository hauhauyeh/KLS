using KLS.API.Helpers;
using KLS.Common;
using KLS.Contract.Services;
using KLS.Models.Cart;
using Microsoft.AspNetCore.Mvc;

namespace KLS.API.Controllers.Web
{
    [AuthorizeWeb]
    [Route("api/web/[controller]")]
    public class CartController : BaseController
    {
        #region --- Member(s) ---

        private readonly ITempSalesService _tempSalesService;
        private readonly ISystemSettingService _systemSettingService;

        #endregion

        #region --- Constructor(s) ---

        public CartController(ITempSalesService tempSalesService, ISystemSettingService systemSettingService)
        {
            _tempSalesService = tempSalesService;
            _systemSettingService = systemSettingService;
        }

        #endregion

        #region --- Method(s) ---

        [HttpGet("settings")]
        public IActionResult GetSettings()
        {
            var enforceStock = _systemSettingService.GetByKey<bool>(GlobalKey.WEB_ENFORCE_STOCK_LIMIT);
            return Ok(new { EnforceStockLimit = enforceStock });
        }

        [HttpGet]
        public IActionResult GetList()
        {
            return Ok(_tempSalesService.GetCartItems());
        }


        [HttpGet("count")]
        public IActionResult GetCount()
        {
            return Ok(_tempSalesService.GetCartItems()?.Count());
        }


        [HttpPost]
        public IActionResult AddCartItem([FromBody] AddToCartReq req)
        {
            var result = _tempSalesService.AddCartItem(req);

            if (result == null)
                return BadRequest();

            return Ok(result);
        }


        [HttpPut]
        public IActionResult UpdateQty([FromBody] WebCartItem cartItem)
        {
            var result = _tempSalesService.UpdateCartQty(cartItem);

            if (result == null)
                return BadRequest();

            return Ok(result);
        }


        [HttpPut("unit")]
        public IActionResult UpdateUnit([FromBody] WebCartItem cartItem)
        {
            var result = _tempSalesService.UpdateCartUnit(cartItem);

            if (result == null)
                return BadRequest();

            return Ok(result);
        }


        [HttpDelete("{id}")]
        public IActionResult Delete(int id)
        {
            _tempSalesService.Delete(id);

            return Ok();
        }


        [HttpDelete("clear")]
        public IActionResult Clear()
        {
            _tempSalesService.ClearCart();

            return Ok();
        }

        #endregion
    }
}
