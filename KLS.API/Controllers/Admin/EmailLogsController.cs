using KLS.API.Helpers;
using KLS.Contract.Services;
using KLS.Models;
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel;
using System.ComponentModel.DataAnnotations;

namespace KLS.API.Controllers.Admin
{
    [AuthorizeAdmin]
    [Route("api/admin/[controller]")]
    [Display(Name = "EmailLog Management", GroupName = "Admin")]
    public class EmailLogsController : BaseController
    {
        #region --- Member(s) ---

        private readonly IEmailLogService _emailLogService;

        #endregion

        #region --- Constructor(s) ---

        public EmailLogsController(IEmailLogService emailLogService)
        {
            _emailLogService = emailLogService;
        }

        #endregion

        #region --- Method(s) ---

        [HttpGet]
        [DisplayName("List EmailLogs")]
        public IActionResult List([FromQuery] EmailLogReq emailLogReq)
        {
            return Ok(_emailLogService.GetPagedList(emailLogReq));
        }

        #endregion
    }
}
