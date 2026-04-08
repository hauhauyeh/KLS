using KLS.API.Helpers;
using KLS.Contract.Services;
using KLS.Models;
using Microsoft.AspNetCore.Mvc;

namespace KLS.API.Controllers.Admin
{
    [Route("api/admin/[controller]")]
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
            var result = _userService.LoginEmployee(loginReq);

            if (!result.Success)
                return Unauthorized(result.ErrorMessage);

            return Ok(result);
        }


        [HttpPost("RefreshToken")]
        public IActionResult RefreshToken([FromBody] RefreshTokenReq tokenReq)
        {
            var result = _userService.RefreshToken(tokenReq);

            if (!result.Success)
                return Unauthorized(result.ErrorMessage);

            return Ok(result);
        }


        [HttpPost("ForgotPassword/{email}")]
        public IActionResult ForgotPassword(string email)
        {
            var user = _userService.GetByEmail(email);

            if (user == null)
                return Unauthorized("Invalid Email");

            var headers = Request.Headers;
            var url = headers?["Origin"].FirstOrDefault() ?? headers?["Referer"].FirstOrDefault();

            var resetUrl = _userService.ForgetPassword(email, url);

            return Ok(new { Message = "Password reset link sent to your email." });
        }


        [HttpPost("ResetPassword")]
        public IActionResult ResetPassword([FromBody] ResetPassword request)
        {
            var isReset = _userService.ResetPassword(request);

            if (!isReset)
                return Unauthorized("Invalid reset link. Request a new one.");

            return Ok();
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
