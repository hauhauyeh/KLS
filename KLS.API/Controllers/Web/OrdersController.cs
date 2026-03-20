using KLS.API.Helpers;
using KLS.Contract.Services;
using KLS.Models;
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel;
using System.ComponentModel.DataAnnotations;

namespace KLS.API.Controllers.Web
{
    [AuthorizeWeb]
    [Route("api/web/[controller]")]
    [Display(Name = "Orders", GroupName = "Web")]
    public class OrdersController : BaseController
    {
        #region --- Member(s) ---

        private readonly ISalesService _salesService;
        private readonly IWebHostEnvironment _env;

        #endregion

        #region --- Constructor(s) ---

        public OrdersController(ISalesService salesService, IWebHostEnvironment env)
        {
            _salesService = salesService;
            _env = env;
        }

        #endregion

        #region --- Method(s) ---

        [HttpGet]
        [DisplayName("List Orders")]
        public IActionResult List([FromQuery] SalesListReq salesListReq)
        {
            return Ok(_salesService.GetWebPagedList(salesListReq));
        }


        [HttpGet("SeePdf/{salesNumber}")]
        public IActionResult SeePdf(int salesNumber)
        {
            var filePath = Path.Combine(_env.WebRootPath, "InvoicePdf", salesNumber + ".pdf");

            if (!System.IO.File.Exists(filePath))
                return NotFound("File not found.");

            var fileStream = new FileStream(filePath, FileMode.Open, FileAccess.Read);
            return File(fileStream, "application/pdf");
        }


        [HttpGet("Details/{salesId}")]
        public IActionResult Details(int salesId)
        {
            return Ok(_salesService.GetSalesDetails(salesId));
        }

        #endregion
    }
}
