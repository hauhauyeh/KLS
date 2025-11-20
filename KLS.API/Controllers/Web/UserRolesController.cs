using KLS.Services.Interfaces;
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel.DataAnnotations;

namespace KLS.API.Controllers.Web
{
    [Route("api/web/[controller]")]
    [Display(Name = "UserRole Management", GroupName = "Web")]
    public class UserRolesController : BaseController
    {
        #region --- Member(s) ---

        private readonly IUserRoleService _userRoleService;

        #endregion

        #region --- Constructor(s) ---

        public UserRolesController(IUserRoleService userRoleService)
        {
            _userRoleService = userRoleService;
        }

        #endregion

        #region --- Method(s) ---



        #endregion
    }
}
