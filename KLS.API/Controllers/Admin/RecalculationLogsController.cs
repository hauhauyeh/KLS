using KLS.API.Helpers;
using KLS.Services.Interfaces;
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel;
using System.ComponentModel.DataAnnotations;

namespace KLS.API.Controllers.Admin
{
    [AuthorizeAdmin]
    [Route("api/admin/[controller]")]
    [Display(Name = "Recalculation Log Management", GroupName = "Admin")]
    public class RecalculationLogsController : BaseController
    {
        #region --- Member(s) ---

        private readonly IRecalculationLogService _recalculationLogService;

        #endregion

        #region --- Constructor(s) ---

        public RecalculationLogsController(IRecalculationLogService recalculationLogService)
        {
            _recalculationLogService = recalculationLogService;
        }

        #endregion

        #region --- Method(s) ---

        [HttpGet]
        [DisplayName("List Logs")]
        public IActionResult List()
        {
            return Ok(_recalculationLogService.GetAllLogs());
        }

        #endregion
    }
}
