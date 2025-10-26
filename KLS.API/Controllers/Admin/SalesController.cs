using KLS.API.Helpers;
using KLS.Models;
using KLS.Services.Interfaces;
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel;
using System.ComponentModel.DataAnnotations;

namespace KLS.API.Controllers.Admin
{
    [AuthorizeAdmin]
    [Route("api/admin/[controller]")]
    [Display(Name = "Sales Management", GroupName = "Customer")]
    public class SalesController : BaseController
    {
        #region --- Member(s) ---

        private readonly ISalesService _salesService;

        #endregion

        #region --- Constructor(s) ---

        public SalesController(ISalesService salesService)
        {
            _salesService = salesService;
        }

        #endregion

        #region --- Method(s) ---

        [HttpGet]
        [DisplayName("List Sales")]
        public IActionResult List([FromQuery] SalesListReq salesListReq)
        {
            return Ok(_salesService.GetAllSales(salesListReq));
        }

        #endregion
    }
}
