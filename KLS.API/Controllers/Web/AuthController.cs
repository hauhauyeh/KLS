using KLS.Contract.Services;
using KLS.Models;
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

        [HttpPost("Login")]
        public IActionResult Login(LoginReq loginReq)
        {
            var result = _userAccountService.LoginUser(loginReq);

            if (!result.Success)
                return Unauthorized(new { result.Success, result.ErrorMessage, result.RequireEmailVerification });

            return Ok(result);
        }


        [HttpPost("RefreshToken")]
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
                return Unauthorized("This email address is not registered in our system");

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


        [HttpPost("ResendEmail/{email}")]
        public IActionResult ResendEmail(string email)
        {
            var user = _userAccountService.GetByEmail(email);

            if (user == null)
                return Unauthorized("This email address is not registered in our system");

            var headers = Request.Headers;
            var url = headers?["Origin"].FirstOrDefault() ?? headers?["Referer"].FirstOrDefault();

            _userAccountService.ResendEmailVerification(email, url);

            return Ok(new { Message = "Email verification link sent to your email." });
        }


        [HttpPost("VerifyEmail/{token}")]
        public IActionResult VerifyEmail(string token)
        {
            var isVerified = _userAccountService.VerifyEmail(token);

            if (!isVerified)
                return Unauthorized("Invalid or expired verification link. Please request a new one.");

            return Ok(new { Message = "Email verified successfully. You can now log in." });
        }

        #endregion
    }
}
