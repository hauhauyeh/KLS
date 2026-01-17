using KLS.API.Helpers;
using KLS.Common;
using KLS.Contract.Services;
using KLS.Models;
using KLS.Services;
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel.DataAnnotations;

namespace KLS.API.Controllers.Admin
{
    [AuthorizeAdmin]
    [Route("api/admin/[controller]")]
    [Display(Name = "Temp Quote Management", GroupName = "Customer")]
    public class TempItemQuotesController : BaseController
    {
        #region --- Member(s) ---

        private readonly ITempItemQuoteService _tempItemQuoteService;

        #endregion

        #region --- Constructor(s) ---

        public TempItemQuotesController(ITempItemQuoteService tempItemQuoteService)
        {
            _tempItemQuoteService = tempItemQuoteService;
        }

        #endregion

        #region --- Method(s) ---

        [HttpGet]
        public IActionResult List([FromQuery] TempItemQuoteReq tempReq)
        {
            return Ok(_tempItemQuoteService.GetList(tempReq));
        }


        [HttpPost]
        public IActionResult Create([FromBody] TempItemQuoteList tempQuote)
        {
            return Ok(_tempItemQuoteService.Create(tempQuote));
        }


        [HttpPut]
        public IActionResult Update([FromBody] TempItemQuoteList tempQuote)
        {
            return Ok(_tempItemQuoteService.Update(tempQuote));
        }


        [HttpDelete("{tempId}")]
        public IActionResult Delete(int tempId)
        {
            _tempItemQuoteService.Delete(tempId);
            return Ok();
        }


        [HttpPost("Clear/{payeeId}")]
        public IActionResult Clear(int payeeId)
        {
            _tempItemQuoteService.Clear(payeeId);
            return Ok();
        }


        #endregion
    }
}
