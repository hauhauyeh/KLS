using KLS.API.Helpers;
using KLS.Common;
using KLS.Contract.Services;
using KLS.Models;
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel.DataAnnotations;

namespace KLS.API.Controllers.Web
{
    [AuthorizeWeb]
    [Route("api/web/[controller]")]
    [Display(Name = "Item Quotes", GroupName = "Web")]
    public class ItemQuotesController : BaseController
    {
        #region --- Member(s) ---

        private readonly IItemQuoteService _itemQuoteService;

        #endregion

        #region --- Constructor(s) ---

        public ItemQuotesController(IItemQuoteService itemQuoteService)
        {
            _itemQuoteService = itemQuoteService;
        }

        #endregion

        #region --- Method(s) ---

        [HttpGet]
        public IActionResult GetList()
        {
            var items = _itemQuoteService.GetByPayee(UserContext.EmpId);
            return Ok(items.Select(c => new { c.ItemId, c.ItemUnitId }));
        }


        [HttpPost]
        public IActionResult Create([FromBody] ItemQuoteCreateReq req)
        {
            _itemQuoteService.Create(req);

            return Ok();
        }


        [HttpDelete("{itemId}/{itemUnitId}")]
        public IActionResult Delete(int itemId, int itemUnitId)
        {
            _itemQuoteService.Delete(UserContext.EmpId, itemId, itemUnitId);

            return Ok();
        }

        #endregion
    }
}
