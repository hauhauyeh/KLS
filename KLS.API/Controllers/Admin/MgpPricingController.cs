using KLS.API.Helpers;
using KLS.Contract.Services;
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel.DataAnnotations;

namespace KLS.API.Controllers.Admin
{
    [AuthorizeAdmin]
    [Route("api/admin/[controller]")]
    [Display(Name = "MGP Pricing", GroupName = "Product")]
    public class MgpPricingController : BaseController
    {
        private readonly IMgpPricingService _mgpPricingService;
        private readonly ICompanyService _companyService;

        public MgpPricingController(
            IMgpPricingService mgpPricingService,
            ICompanyService companyService)
        {
            _mgpPricingService = mgpPricingService;
            _companyService = companyService;
        }

        [HttpGet("price-sheet-targets")]
        [PermissionKey("Customer.Customer.Update")]
        public IActionResult PriceSheetTargets()
        {
            var companyCode = _companyService.GetDefault()?.CompanyCode?.Trim();
            if (!string.Equals(companyCode, "MGP", StringComparison.OrdinalIgnoreCase))
                return Forbid();

            return Ok(_mgpPricingService.GetPriceSheetTargets());
        }
    }
}
