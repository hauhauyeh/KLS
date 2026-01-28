using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Text.Json;
using System.Threading.Tasks;
using System.Web;

namespace KLS.Services
{
    public class UserAccountService : BaseService, IUserAccountService
    {
        private readonly IJWTService _jWTService;
        private readonly IUserRoleService _userRoleService;
        private readonly IEmailSettingService _emailSettingService;
        private readonly IEmailService _emailService;

        public UserAccountService(IUnitOfWork uow,
            IJWTService jWTService,
            IUserRoleService userRoleService,
            IEmailSettingService emailSettingService,
            IEmailService emailService) : base(uow)
        {
            _jWTService = jWTService;
            _userRoleService = userRoleService;
            _emailSettingService = emailSettingService;
            _emailService = emailService;
        }

        public UserAccount? CheckUserUsername(LoginReq loginReq)
        {
            return Uow.UserAccounts
                .Find(e => (e.Username == loginReq.Username || e.Email == loginReq.Username) && !e.Inactive).FirstOrDefault();
        }

        public UserAccount GetById(int userId)
        {
            return Uow.UserAccounts.GetById(userId);
        }

        public UserAccount? GetByEmail(string email)
        {
            return Uow.UserAccounts.Find(e => e.Email == email).FirstOrDefault();
        }

        public LoginResult LoginUser(LoginReq loginReq, string ipAddress)
        {
            var user = CheckUserUsername(loginReq);

            if (user == null || string.IsNullOrEmpty(user.PasswordHash))
                return new LoginResult { Success = false, ErrorMessage = "Username/Email or password is incorrect" };

            if (Utilities.Decrypt(user.PasswordHash) != loginReq.Password)
                return new LoginResult { Success = false, ErrorMessage = "Password is incorrect" };

            var refreshToken = _jWTService.GenerateRefreshToken();
            user.RefToken = refreshToken;
            user.RefTokenExpire = DateTime.Now.AddDays(_jWTService.RefreshTokenValidity());
            UpdateToken(user);

            var role = _userRoleService.GetById(user.RoleId);

            //--claim
            var jwtClaim = new JWTClaim
            {
                Portal = EnumHelper.Portal.Web.ToString(),
                Username = user.Username,
                PayeeId = user.PayeeId,
                UserId = user.UserId,
                RefreshToken = refreshToken,
                RefTokenExpire = user.RefTokenExpire,
                RoleId = user.RoleId,
                IsAdmin = role.IsAdmin
            };

            var token = _jWTService.GenerateJwtToken(jwtClaim);

            return new LoginResult
            {
                Success = true,
                Token = token,
                RefreshToken = refreshToken,
                Username = user.Username,
                IsAdmin = role.IsAdmin,
                IsSalesRole = role.IsSalesRole
            };
        }

        public LoginResult RefreshToken(RefreshTokenReq tokenReq)
        {
            var jwtClaim = _jWTService.ValidateExpiredToken(tokenReq.AccessToken);

            if (jwtClaim == null)
                return new LoginResult { Success = false, ErrorMessage = "Invalid or expired token." };

            if (jwtClaim.RefreshToken != tokenReq.RefreshToken || jwtClaim.RefTokenExpire <= DateTime.Now)
                return new LoginResult { Success = false, ErrorMessage = "Invalid or expired refresh token." };

            var newToken = _jWTService.GenerateJwtToken(jwtClaim);

            var role = _userRoleService.GetById(jwtClaim.RoleId);

            return new LoginResult
            {
                Success = true,
                Token = newToken,
                RefreshToken = jwtClaim.RefreshToken,
                Username = jwtClaim.Username,
                IsAdmin = role.IsAdmin,
                IsSalesRole = role?.IsSalesRole ?? false
            };
        }

        public void UpdateToken(UserAccount userAccount)
        {
            var existing = GetById(userAccount.UserId);

            if (existing != null)
            {
                existing.RefToken = userAccount.RefToken;
                existing.RefTokenExpire = userAccount.RefTokenExpire;

                Uow.UserAccounts.Update(existing);
                Uow.Commit();
            }
        }

        public string ForgetPassword(string email, string url)
        {
            var user = GetByEmail(email);

            if (user == null)
                return null;

            // Generate token
            var token = TokenHelper.GenerateToken();

            user.ResetTokenHash = token;
            user.ResetTokenExpire = DateTime.UtcNow.AddMinutes(15); // 15 min expiry
            user.UpdatedAt = DateTime.UtcNow;

            Uow.UserAccounts.Update(user);
            Uow.Commit();

            // Build reset link
            string resetUrl = $"{url}/resetpassword/{Uri.EscapeDataString(token)}";

            var subject = "Reset your password";

            var model = new ForgotPassword
            {
                Username = user.Username ?? user.Email,
                ResetUrl = resetUrl
            };

            string mailBody = _emailService.RenderEmailTemplate("~/Views/ForgotPassword.cshtml", model);

            EmailSetting setting = _emailSettingService.GetSetting();

            Task.Factory.StartNew(() => _emailService.SendEmail(setting, user.Email, subject, mailBody, null), TaskCreationOptions.LongRunning)
                .ContinueWith((t) => { });

            return resetUrl;
        }

        public bool ResetPassword(ResetPassword resetPassword)
        {
            string? token = HttpUtility.UrlDecode(resetPassword.Token);

            var user = Uow.UserAccounts.Find(u => u.ResetTokenHash == token && u.ResetTokenExpire > DateTime.UtcNow).FirstOrDefault();

            if (user == null)
                return false;

            user.PasswordHash = Utilities.Encrypt(resetPassword.NewPassword);
            user.ResetTokenHash = null;
            user.ResetTokenExpire = null;
            user.UpdatedAt = DateTime.UtcNow;

            Uow.UserAccounts.Update(user);
            Uow.Commit();

            return true;
        }
    }
}
