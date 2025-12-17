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
    public class SystemUserService : BaseService, ISystemUserService
    {
        private readonly IEmployeeService _employeeService;
        private readonly IJWTService _jWTService;
        private readonly ISystemSettingService _settingService;
        private readonly ISystemRoleService _roleService;
        private readonly IEmailSettingService _emailSettingService;

        public SystemUserService(IUnitOfWork uow, IJWTService jWTService, IEmployeeService employeeService, ISystemSettingService settingService, ISystemRoleService roleService, IEmailSettingService emailSettingService) : base(uow)
        {
            _jWTService = jWTService;
            _employeeService = employeeService;
            _settingService = settingService;
            _roleService = roleService;
            _emailSettingService = emailSettingService;
        }

        public SystemUser? CheckEmpUsername(LoginReq loginReq)
        {
            return Uow.SystemUsers
                .Find(e => e.Username == loginReq.Username && !e.Inactive && e.PayeeId.ToString().StartsWith("1"))
                .FirstOrDefault();
        }

        public SystemUser GetById(int userId)
        {
            return Uow.SystemUsers.GetById(userId);
        }

        public SystemUser? GetByEmail(string email)
        {
            return Uow.SystemUsers.Find(e => e.Email == email).FirstOrDefault();
        }

        public bool UserNameExists(string username, int payeeId)
        {
            return Uow.SystemUsers.Exists(c => c.Username.ToLower() == username.ToLower() && c.PayeeId != payeeId);
        }

        public void UpdateUser(SystemUser user)
        {
            user.UpdatedAt = DateTime.UtcNow;

            Uow.SystemUsers.Update(user);
            Uow.Commit();
        }

        public void UpdateToken(SystemUser user)
        {
            var existing = GetById(user.SystemUserId);

            if (existing != null)
            {
                existing.RefToken = user.RefToken;
                existing.RefTokenExpire = user.RefTokenExpire;

                Uow.SystemUsers.Update(existing);
                Uow.Commit();
            }
        }

        public LoginResult LoginEmployee(LoginReq loginReq, string ipAddress)
        {
            var user = CheckEmpUsername(loginReq);

            if (user == null || string.IsNullOrEmpty(user.PasswordHash))
                return new LoginResult { Success = false, ErrorMessage = "Username or password is incorrect" };

            if (Utilities.Decrypt(user.PasswordHash) != loginReq.Password)
                return new LoginResult { Success = false, ErrorMessage = "Password is incorrect" };

            var emp = _employeeService.GetById(user.PayeeId);

            if (emp == null)
                return new LoginResult { Success = false, ErrorMessage = "Username or password is incorrect" };

            if (emp.HasOutsideAccess)
            {
                var allowedIp = _settingService.GetByKey<string>(GlobalKey.SYS_IPADDRESS);

                if (ipAddress != allowedIp)
                {
                    return new LoginResult { Success = false, ErrorMessage = "You can't login right now" };
                }
            }

            var refreshToken = _jWTService.GenerateRefreshToken();
            user.RefToken = refreshToken;
            user.RefTokenExpire = DateTime.Now.AddDays(_jWTService.RefreshTokenValidity());
            UpdateToken(user);

            var role = _roleService.GetById(user.SystemRoleId);

            //--claim
            var jwtClaim = new JWTClaim
            {
                Portal = EnumHelper.Portal.Admin.ToString(),
                Username = user.Username,
                PayeeId = user.PayeeId,
                UserId = user.SystemUserId,
                RefreshToken = refreshToken,
                RefTokenExpire = user.RefTokenExpire,
                RoleId = user.SystemRoleId,
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
                IsSalesRole = role.IsSalesRole,
                EmpId = user.PayeeId,
                EmpSortName = string.IsNullOrEmpty(emp.FirstName) || string.IsNullOrEmpty(emp.LastName)
                    ? ""
                    : emp.FirstName[0].ToString() + emp.LastName[0].ToString()
            };
        }

        public LoginResult RefreshToken(RefreshTokenReq tokenReq)
        {
            var jwtClaim = _jWTService.ValidateExpiredToken(tokenReq.AccessToken);

            if (jwtClaim == null)
                return new LoginResult { Success = false, ErrorMessage = "Invalid or expired token." };

            var emp = _employeeService.GetById(jwtClaim.PayeeId);

            if (emp == null)
                return new LoginResult { Success = false, ErrorMessage = "User not found." };

            if (jwtClaim.RefreshToken != tokenReq.RefreshToken || jwtClaim.RefTokenExpire <= DateTime.Now)
                return new LoginResult { Success = false, ErrorMessage = "Invalid or expired refresh token." };


            var newToken = _jWTService.GenerateJwtToken(jwtClaim);

            var role = _roleService.GetById(jwtClaim.RoleId);

            var sortName = string.IsNullOrEmpty(emp.FirstName) || string.IsNullOrEmpty(emp.LastName)
                   ? ""
                   : emp.FirstName[0].ToString() + emp.LastName[0].ToString();

            return new LoginResult
            {
                Success = true,
                Token = newToken,
                RefreshToken = jwtClaim.RefreshToken,
                Username = jwtClaim.Username,
                IsAdmin = role.IsAdmin,
                IsSalesRole = role?.IsSalesRole ?? false,
                EmpId = jwtClaim.PayeeId,
                EmpSortName = sortName
            };
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

            Uow.SystemUsers.Update(user);
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

            var user = Uow.SystemUsers.Find(u => u.ResetTokenHash == token && u.ResetTokenExpire > DateTime.UtcNow).FirstOrDefault();

            if (user == null)
                return false;

            user.PasswordHash = Utilities.Encrypt(resetPassword.NewPassword);
            user.ResetTokenHash = null;
            user.ResetTokenExpire = null;
            user.UpdatedAt = DateTime.UtcNow;

            Uow.SystemUsers.Update(user);
            Uow.Commit();

            return true;
        }

        public void Logout()
        {
            var user = GetById(UserContext.SystemUserId);

            if (user != null)
            {
                user.RefToken = null;
                user.RefTokenExpire = null;
                user.UpdatedAt = DateTime.UtcNow;

                Uow.SystemUsers.Update(user);
                Uow.Commit();
            }
        }
    }
}
