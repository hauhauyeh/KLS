using KLS.API.Helpers;
using KLS.Services.Interfaces;
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel.DataAnnotations;

namespace KLS.API.Controllers.Admin
{
    [AuthorizeAdmin]
    [Route("api/admin/[controller]")]
    [Display(Name = "VendorPmt Management", GroupName = "Admin")]
    public class VendorPaymentsController : BaseController
    {
        #region --- Member(s) ---

        private readonly IVendorPaymentService _vendorPaymentService;

        #endregion

        #region --- Constructor(s) ---

        public VendorPaymentsController(IVendorPaymentService vendorPaymentService)
        {
            _vendorPaymentService = vendorPaymentService;
        }

        #endregion

        #region --- Method(s) ---



        #endregion
    }
}
