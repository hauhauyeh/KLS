using KLS.API.Helpers;
using KLS.Models;
using KLS.Services;
using KLS.Services.Interfaces;
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel;
using System.ComponentModel.DataAnnotations;

namespace KLS.API.Controllers.Admin
{
    [AuthorizeAdmin]
    [Route("api/admin/[controller]")]
    [Display(Name = "CheckRegister Management", GroupName = "Admin")]
    public class CheckRegisterController : BaseController
    {
        #region --- Member(s) ---

        private readonly IVendorPmtService _vendorPmtService;

        #endregion

        #region --- Constructor(s) ---

        public CheckRegisterController(IVendorPmtService vendorPmtService)
        {
            _vendorPmtService = vendorPmtService;
        }

        #endregion

        #region --- Method(s) ---

        [HttpGet]
        [DisplayName("List CheckRegister")]
        public IActionResult List([FromQuery] CheckRegisterReq checkRegisterReq)
        {
            return Ok(_vendorPmtService.GetCheckRegister(checkRegisterReq));
        }

        #endregion
    }
}
