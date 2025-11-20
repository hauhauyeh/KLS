using KLS.API.Helpers;
using KLS.Common;
using KLS.Models;
using KLS.Services.Interfaces;
using Microsoft.AspNetCore.Mvc;

namespace KLS.API.Controllers.Sales
{
    [Route("api/sales/[controller]")]
    public class AuthController : BaseController
    {
        #region --- Member(s) ---

        private readonly ISystemUserService _userService;

        #endregion

        #region --- Constructor(s) ---

        public AuthController(ISystemUserService userService)
        {
            _userService = userService;
        }

        #endregion

        #region --- Method(s) ---

        [HttpPost("login")]
        public IActionResult EmpLogin(LoginReq loginReq)
        {
            var ipAddress = Utilities.GetIpAddress(HttpContext);
            var result = _userService.LoginEmployee(loginReq, ipAddress);

            if (!result.Success)
                return Unauthorized(result.ErrorMessage);

            return Ok(result);
        }


        [HttpPost("refreshtoken")]
        public IActionResult RefreshToken([FromBody] RefreshTokenReq tokenReq)
        {
            var result = _userService.RefreshToken(tokenReq);

            if (!result.Success)
                return Unauthorized(result.ErrorMessage);

            return Ok(result);
        }


        [AuthorizeAdmin]
        [HttpPost("logout")]
        public IActionResult Logout()
        {
            _userService.Logout();
            return Ok();
        }

        #endregion
    }
}
