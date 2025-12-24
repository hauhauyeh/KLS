using KLS.API.Helpers;
using KLS.Contract.Services;
using KLS.Models;
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

        #endregion
    }
}
