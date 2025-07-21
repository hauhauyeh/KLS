using KLS.API.Helpers;
using KLS.Services.Interfaces;
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel.DataAnnotations;

namespace KLS.API.Controllers.Admin
{
    [AuthorizeAdmin]
    [Route("api/admin/[controller]")]
    [Display(Name = "Term Management", GroupName = "Admin")]
    public class TermsController : BaseController
    {
        #region --- Member(s) ---

        private readonly ITermService _termService;

        #endregion

        #region --- Constructor(s) ---

        public TermsController(ITermService termService)
        {
            _termService = termService;
        }

        #endregion
    }
}
