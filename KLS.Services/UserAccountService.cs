using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Models;
using KLS.Services.Interfaces;
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

        public UserAccountService(IUnitOfWork uow, IJWTService jWTService, IUserRoleService userRoleService, IEmailSettingService emailSettingService) : base(uow)
        {
            _jWTService = jWTService;
            _userRoleService = userRoleService;
            _emailSettingService = emailSettingService;
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

            var token = _jWTService.GenerateJwtToken(user);
            var role = _userRoleService.GetById(user.RoleId);

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
            var userJson = _jWTService.ValidateExpiredToken(tokenReq.AccessToken);

            if (string.IsNullOrEmpty(userJson))
                return new LoginResult { Success = false, ErrorMessage = "Invalid or expired token." };

            var user = JsonSerializer.Deserialize<UserAccount>(userJson);
            if (user == null)
                return new LoginResult { Success = false, ErrorMessage = "User info malformed." };

            //var emp = _employeeService.GetById(user.PayeeId);

            //if (emp == null)
            //    return new LoginResult { Success = false, ErrorMessage = "User not found." };

            if (user.RefToken != tokenReq.RefreshToken || user.RefTokenExpire <= DateTime.Now)
                return new LoginResult { Success = false, ErrorMessage = "Invalid or expired refresh token." };


            var newToken = _jWTService.GenerateJwtToken(user);

            var role = _userRoleService.GetById(user.RoleId);

            //var sortName = string.IsNullOrEmpty(emp.FirstName) || string.IsNullOrEmpty(emp.LastName)
            //       ? ""
            //       : emp.FirstName[0].ToString() + emp.LastName[0].ToString();

            return new LoginResult
            {
                Success = true,
                Token = newToken,
                RefreshToken = user.RefToken,
                Username = user.Username,
                IsAdmin = role.IsAdmin,
                IsSalesRole = role?.IsSalesRole ?? false,
                //EmpId = user.PayeeId,
                //EmpSortName = sortName
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

            string mailBody = EmailService.RenderEmailTemplate("~/Views/ForgotPassword.cshtml", model);

            EmailSetting setting = _emailSettingService.GetSetting();
            Task.Factory.StartNew(() => EmailService.SendEmail(setting, user.Email, subject, mailBody, null), TaskCreationOptions.LongRunning)
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
