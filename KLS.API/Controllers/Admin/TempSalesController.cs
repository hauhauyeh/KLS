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
    [Display(Name = "Temp Order Management", GroupName = "Customer")]
    public class TempSalesController : BaseController
    {
        #region --- Member(s) ---

        private readonly ITempSalesService _tempSalesService;

        #endregion

        #region --- Constructor(s) ---

        public TempSalesController(ITempSalesService tempSalesService)
        {
            _tempSalesService = tempSalesService;
        }

        #endregion

        #region --- Method(s) ---

        [HttpGet]
        public IActionResult List([FromQuery] TempSalesReq tempReq)
        {
            return Ok(_tempSalesService.GetList(tempReq));
        }


        [HttpPost]
        public IActionResult Create([FromBody] TempSalesItem tempItem)
        {
            return Ok(_tempSalesService.Create(tempItem));
        }


        [HttpPut]
        public IActionResult Update([FromBody] TempSalesItem tempItem)
        {
            return Ok(_tempSalesService.Update(tempItem));
        }


        [HttpDelete("{tempId}")]
        public IActionResult Delete(int tempId)
        {
            _tempSalesService.Delete(tempId);
            return Ok();
        }


        [HttpPost("Clear")]
        public IActionResult Clear([FromBody] TempSalesReq tempReq)
        {
            _tempSalesService.Clear(tempReq);
            return Ok();
        }


        [HttpGet("DraftCustomers")]
        public IActionResult DraftCustomers()
        {
            return Ok(_tempSalesService.DraftCustomers());
        }


        [HttpGet("Search")]
        public IActionResult Search([FromQuery] TempSalesReq tempReq)
        {
            return Ok(_tempSalesService.Search(tempReq));
        }

        #endregion
    }
}
