using KLS.API.Helpers;
using KLS.Services;
using KLS.Services.Interfaces;
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel.DataAnnotations;

namespace KLS.API.Controllers.Admin
{
    [AuthorizeAdmin]
    [Route("api/admin/[controller]")]
    [Display(Name = "ChartOfAccountType Management", GroupName = "Admin")]
    public class ChartOfAccountTypesController : BaseController
    {
        #region --- Member(s) ---

        private readonly IChartOfAccountTypeService _accountTypeService;

        #endregion

        #region --- Constructor(s) ---

        public ChartOfAccountTypesController(IChartOfAccountTypeService chartOfAccountTypeService)
        {
            _accountTypeService = chartOfAccountTypeService;
        }

        #endregion

        #region --- Method(s) ---

        [HttpGet("{id}")]
        public IActionResult GetById(int id)
        {
            return Ok(_accountTypeService.GetById(id));
        }

        #endregion
    }
}
