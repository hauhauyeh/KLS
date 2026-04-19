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
        private readonly ISystemUserService _systemUserService;
        private readonly ICustomerService _customerService;

        #endregion

        #region --- Constructor(s) ---

        public AuthController(IUserAccountService userAccountService, ISystemUserService systemUserService, ICustomerService customerService)
        {
            _userAccountService = userAccountService;
            _systemUserService = systemUserService;
            _customerService = customerService;
        }

        #endregion

        #region --- Method(s) ---

        [HttpPost("Register")]
        public IActionResult Register([FromBody] RegisterReq registerReq)
        {
            if (!string.IsNullOrWhiteSpace(registerReq.PayeeName) && _customerService.NameExists(registerReq.PayeeName, 0))
                return Conflict("Company name already exists.");

            if (_userAccountService.EmailExists(registerReq.Email, 0))
                return Conflict("Email already registered.");

            if (_userAccountService.UsernameExists(registerReq.Username, 0))
                return Conflict("Username already registered.");

            if (!string.IsNullOrWhiteSpace(registerReq.Phone) && _userAccountService.PhoneExists(registerReq.Phone, 0))
                return Conflict("Phone number already registered.");

            var headers = Request.Headers;
            var url = headers?["Origin"].FirstOrDefault() ?? headers?["Referer"].FirstOrDefault();

            _customerService.Register(registerReq, url);

            return Ok();
        }


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


        [HttpPost("SalesLogin")]
        public IActionResult SalesLogin(LoginReq loginReq)
        {
            var result = _systemUserService.LoginEmployee(loginReq);

            if (!result.Success)
                return Unauthorized(new { result.Success, result.ErrorMessage });

            if (!result.IsSalesRole)
                return Unauthorized(new { Success = false, ErrorMessage = "Access denied. Only sales representatives can login here." });

            return Ok(result);
        }


        [HttpPost("SalesRefreshToken")]
        public IActionResult SalesRefreshToken([FromBody] RefreshTokenReq tokenReq)
        {
            var result = _systemUserService.RefreshToken(tokenReq);

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


        [HttpPost("SetPassword")]
        public IActionResult SetPassword([FromBody] SetPasswordReq req)
        {
            var result = _userAccountService.SetPasswordFromToken(req);

            if (!result.Success && result.Token == null && result.ErrorMessage != null && !result.ErrorMessage.Contains("pending"))
                return BadRequest(new { result.ErrorMessage });

            return Ok(result);
        }


        [HttpPost("VerifyEmail/{token}")]
        public IActionResult VerifyEmail(string token)
        {
            var isVerified = _userAccountService.VerifyEmail(token);

            if (!isVerified)
                return Unauthorized("Invalid or expired verification link. Please request a new one.");

            return Ok(new { Message = "Email verified successfully. You can now log in." });
        }


        [HttpPost("Logout")]
        public IActionResult Logout()
        {
            _userAccountService.Logout();
            return Ok();
        }


        [HttpPost("SalesLogout")]
        public IActionResult SalesLogout()
        {
            _systemUserService.Logout();
            return Ok();
        }

        #endregion
    }
}
