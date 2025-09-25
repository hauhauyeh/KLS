using KLS.API.Helpers;
using KLS.Services.Interfaces;
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel.DataAnnotations;

namespace KLS.API.Controllers.Admin
{
    [AuthorizeAdmin]
    [Route("api/admin/[controller]")]
    [Display(Name = "VendorPmt Management", GroupName = "Admin")]
    public class VendorPmtsController : BaseController
    {
        #region --- Member(s) ---

        private readonly IVendorPmtService _vendorPmtService;

        #endregion

        #region --- Constructor(s) ---

        public VendorPmtsController(IVendorPmtService vendorPmtService)
        {
            _vendorPmtService = vendorPmtService;
        }

        #endregion

        #region --- Method(s) ---



        #endregion
    }
}
