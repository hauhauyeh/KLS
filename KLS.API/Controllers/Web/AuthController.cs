using KLS.Common;
using KLS.Models;
using KLS.Services.Interfaces;
using Microsoft.AspNetCore.Mvc;

namespace KLS.API.Controllers.Web
{
    [Route("api/web/[controller]")]
    public class AuthController : BaseController
    {
        #region --- Member(s) ---

        private readonly IUserAccountService _userAccountService;

        #endregion

        #region --- Constructor(s) ---

        public AuthController(IUserAccountService userAccountService)
        {
            _userAccountService = userAccountService;
        }

        #endregion

        #region --- Method(s) ---

        [HttpPost("login")]
        public IActionResult UserLogin(LoginReq loginReq)
        {
            var ipAddress = Utilities.GetIpAddress(HttpContext);
            var result = _userAccountService.LoginUser(loginReq, ipAddress);

            if (!result.Success)
                return Unauthorized(result.ErrorMessage);

            return Ok(result);
        }


        [HttpPost("refreshtoken")]
        public IActionResult RefreshToken([FromBody] RefreshTokenReq tokenReq)
        {
            var result = _userAccountService.RefreshToken(tokenReq);

            if (!result.Success)
                return Unauthorized(result.ErrorMessage);

            return Ok(result);
        }


        [HttpPost("ForgotPassword/{email}")]
        public IActionResult ForgotPassword(string email)
        {
            var user = _userAccountService.GetByEmail(email);

            if (user == null)
                return Unauthorized("Invalid Email");

            var headers = Request.Headers;
            var url = headers?["Origin"].FirstOrDefault() ?? headers?["Referer"].FirstOrDefault();

            var resetUrl = _userAccountService.ForgetPassword(email, url);

            return Ok(new { Message = "Password reset link sent to your email." });
        }


        [HttpPost("ResetPassword")]
        public IActionResult ResetPassword([FromBody] ResetPassword request)
        {
            var isReset = _userAccountService.ResetPassword(request);

            if (!isReset)
                return Unauthorized("Invalid reset link. Request a new one.");

            return Ok();
        }

        #endregion
    }
}
