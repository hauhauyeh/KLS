using KLS.Models;
using KLS.Services;
using KLS.Services.Interfaces;
using Microsoft.AspNetCore.Mvc;
using Org.BouncyCastle.Ocsp;
using System.ComponentModel;
using System.ComponentModel.DataAnnotations;

namespace KLS.API.Controllers.Admin
{
    //[AuthorizeAdmin]
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
        public IActionResult GetAllEmailLogs([FromQuery] EmailLogReq emailLogReq)
        {
            return Ok(_emailLogService.GetEmailLogs(emailLogReq));
        }

        #endregion
    }
}
