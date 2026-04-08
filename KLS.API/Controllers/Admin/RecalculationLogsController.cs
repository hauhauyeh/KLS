using KLS.API.Helpers;
using KLS.Contract.Services;
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
        [PermissionKey("Admin.RecalcLog.List")]
        public IActionResult List()
        {
            return Ok(_recalculationLogService.GetList());
        }

        #endregion
    }
}
