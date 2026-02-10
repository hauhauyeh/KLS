using KLS.API.Helpers;
using KLS.Contract.Services;
using KLS.Models;
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel;

namespace KLS.API.Controllers.Admin
{
    [AuthorizeAdmin]
    [Route("api/admin/[controller]")]
    public class CheckTrackersController : BaseController
    {
        #region --- Member(s) ---

        private readonly ICheckTrackerService _checkTrackerService;

        #endregion

        #region --- Constructor(s) ---

        public CheckTrackersController(ICheckTrackerService checkTrackerService)
        {
            _checkTrackerService = checkTrackerService;
        }

        #endregion

        #region --- Method(s) ---

        [HttpGet("{accountId}")]
        public IActionResult Get(int accountId)
        {
            return Ok(_checkTrackerService.GetCheckNumber(accountId));
        }

        #endregion
    }
}
