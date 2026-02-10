using KLS.API.Helpers;
using KLS.Contract.Services;
using Microsoft.AspNetCore.Mvc;


namespace KLS.API.Controllers.Admin
{
    [AuthorizeAdmin]
    [Route("api/admin/[controller]")]
    public class SystemSettingsController : BaseController
    {
        #region --- Member(s) ---

        private readonly ISystemSettingService _systemSettingService;

        #endregion

        #region --- Constructor(s) ---

        public SystemSettingsController(ISystemSettingService systemSettingService)
        {
            _systemSettingService = systemSettingService;
        }

        #endregion

        #region --- Method(s) ---

        [HttpGet("{key}")]
        public IActionResult GetByKey(string key)
        {
            return Ok(_systemSettingService.GetByKey<string>(key));
        }

        #endregion
    }
}
