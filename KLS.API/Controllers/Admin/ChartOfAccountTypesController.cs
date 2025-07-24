using KLS.Services.Interfaces;
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel.DataAnnotations;

namespace KLS.API.Controllers.Admin
{
    //[AuthorizeAdmin]
    [Route("api/admin/[controller]")]
    [Display(Name = "ChartOfAccountType Management", GroupName = "Admin")]
    public class ChartOfAccountTypesController : BaseController
    {
        #region --- Member(s) ---

        private readonly IChartOfAccountTypeService _chartOfAccountTypeService;

        #endregion

        #region --- Constructor(s) ---

        public ChartOfAccountTypesController(IChartOfAccountTypeService chartOfAccountTypeService)
        {
            _chartOfAccountTypeService = chartOfAccountTypeService;
        }

        #endregion

        #region --- Method(s) ---



        #endregion
    }
}
