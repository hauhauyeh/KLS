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
    [Display(Name = "ItemQuote Management", GroupName = "Admin")]
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

        [HttpPost("Build")]
        public IActionResult Build([FromBody] ItemQuoteBuildReq buildReq)
        {
            return Ok(_itemQuoteService.Build(buildReq));
        }


        [HttpPost("Clear/{payeeId}")]
        public IActionResult Clear(int payeeId)
        {
            _itemQuoteService.Clear(payeeId);
            return Ok();
        }


        [HttpPost("Inject/{payeeId}")]
        public IActionResult Inject(int payeeId)
        {
            _itemQuoteService.Inject(payeeId);
            return Ok();
        }


        [HttpPost("Save/{payeeId}")]
        public IActionResult Save(int payeeId)
        {
            return Ok(_itemQuoteService.Save(payeeId));
        }


        [HttpGet("OwnCount/{payeeId}")]
        public IActionResult OwnCount(int payeeId)
        {
            return Ok(_itemQuoteService.OwnCount(payeeId));
        }


        [HttpPut]
        public IActionResult Update([FromBody] TargetQuotePrice quotePrice)
        {
            return Ok(_itemQuoteService.Update(quotePrice));
        }


        [HttpDelete("{itemQuoteId}")]
        public IActionResult Delete(int itemQuoteId)
        {
            _itemQuoteService.Delete(itemQuoteId);
            return Ok();
        }

        #endregion
    }
}
