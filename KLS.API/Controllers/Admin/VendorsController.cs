using KLS.API.Helpers;
using KLS.Services.Interfaces;
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel.DataAnnotations;

namespace KLS.API.Controllers.Admin
{
    [AuthorizeAdmin]
    [Route("api/admin/[controller]")]
    [Display(Name = "Vendor Management", GroupName = "Admin")]
    public class VendorsController : BaseController
    {
        #region --- Member(s) ---

        private readonly IVendorService _vendorService;

        #endregion

        #region --- Constructor(s) ---

        public VendorsController(IVendorService vendorService)
        {
            _vendorService = vendorService;
        }

        #endregion
    }
}
