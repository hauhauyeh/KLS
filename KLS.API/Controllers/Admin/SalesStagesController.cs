using KLS.API.Helpers;
using KLS.Services.Interfaces;
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel.DataAnnotations;

namespace KLS.API.Controllers.Admin
{
    [AuthorizeAdmin]
    [Route("api/admin/[controller]")]
    [Display(Name = "SalesStage Management", GroupName = "Admin")]
    public class SalesStagesController : BaseController
    {
        #region --- Member(s) ---

        private readonly ISalesStageService _salesStageService;

        #endregion

        #region --- Constructor(s) ---

        public SalesStagesController(ISalesStageService salesStageService)
        {
            _salesStageService = salesStageService;
        }

        #endregion

        #region --- Method(s) ---

        [HttpGet]
        public IActionResult List()
        {
            return Ok(_salesStageService.GetAllSalesStages());
        }

        #endregion
    }
}
