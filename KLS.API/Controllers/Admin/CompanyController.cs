using KLS.API.Helpers;
using KLS.Contract.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel.DataAnnotations;

namespace KLS.API.Controllers.Admin
{
    [Route("api/admin/[controller]")]
    [Display(Name = "Company Management", GroupName = "Admin")]
    public class CompanyController : BaseController
    {
        #region --- Member(s) ---

        private readonly ICompanyService _companyService;

        #endregion

        #region --- Constructor(s) ---

        public CompanyController(ICompanyService companyService)
        {
            _companyService = companyService;
        }

        #endregion

        #region --- Method(s) ---

        [AuthorizeAdmin]
        [HttpGet]
        public IActionResult GetDefault()
        {
            return Ok(_companyService.GetDefault());
        }


        [AllowAnonymous]
        [HttpGet("Name")]
        public IActionResult GetName()
        {
            var company = _companyService.GetDefault();

            return Ok(new { company.DisplayName, company.CompanyCode });
        }

        #endregion
    }
}
