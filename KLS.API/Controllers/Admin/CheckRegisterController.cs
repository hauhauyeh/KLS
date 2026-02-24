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
    [Display(Name = "Check Register Management", GroupName = "Accounting")]
    public class CheckRegisterController : BaseController
    {
        #region --- Member(s) ---

        private readonly IVendorPaymentService _vendorPmtService;

        #endregion

        #region --- Constructor(s) ---

        public CheckRegisterController(IVendorPaymentService vendorPmtService)
        {
            _vendorPmtService = vendorPmtService;
        }

        #endregion

        #region --- Method(s) ---

        [HttpGet]
        [DisplayName("List Check Register")]
        public IActionResult List([FromQuery] CheckRegisterReq checkRegisterReq)
        {
            return Ok(_vendorPmtService.GetPagedCheckRegister(checkRegisterReq));
        }

        #endregion
    }
}
