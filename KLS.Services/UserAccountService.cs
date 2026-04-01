using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Models;
using Newtonsoft.Json.Linq;
using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Security.Policy;
using System.Text;
using System.Text.Json;
using System.Threading.Tasks;
using System.Web;
using System.Xml;
using Twilio.Jwt.AccessToken;

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
                .Find(e => (e.Username.ToLower() == loginReq.Username.ToLower() || e.Email.ToLower() == loginReq.Username.ToLower()) && !e.Inactive).FirstOrDefault();
        }

        public UserAccount GetById(int userId)
        {
            return Uow.UserAccounts.GetById(userId);
        }

        public UserAccount? GetByEmail(string email)
        {
            return Uow.UserAccounts.Find(e => e.Email == email).FirstOrDefault();
        }

        public LoginResult LoginUser(LoginReq loginReq)
        {
            var user = CheckUserUsername(loginReq);

            if (user == null || string.IsNullOrEmpty(user.PasswordHash))
                return new LoginResult { Success = false, ErrorMessage = "Email or password is incorrect" };

            if (Utilities.Decrypt(user.PasswordHash) != loginReq.Password)
                return new LoginResult { Success = false, ErrorMessage = "Password is incorrect" };

            // EMAIL VERIFICATION CHECK
            if (!user.IsEmailVerified)
            {
                return new LoginResult
                {
                    Success = false,
                    ErrorMessage = "Email is not verified. Please verify your email",
                    RequireEmailVerification = true
                };
            }

            // IsApproved
            var customer = Uow.Customers.GetById(user.PayeeId);

            if (!customer.IsApproved)
            {
                return new LoginResult
                {
                    Success = false,
                    ErrorMessage = "Your account has not been approved yet"
                };
            }

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
                IsPriceShow = customer.IsPriceShow
            };
        }

        public LoginResult LoginByPayeeId(int payeeId)
        {
            var user = Uow.UserAccounts.Find(u => u.PayeeId == payeeId && !u.Inactive).FirstOrDefault();

            if (user == null)
                return new LoginResult { Success = false, ErrorMessage = "No web account found for this customer." };

            var refreshToken = _jWTService.GenerateRefreshToken();
            user.RefToken = refreshToken;
            user.RefTokenExpire = DateTime.Now.AddDays(_jWTService.RefreshTokenValidity());
            UpdateToken(user);

            var role = _userRoleService.GetById(user.RoleId);

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
                IsAdmin = role.IsAdmin
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
                IsAdmin = role.IsAdmin
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

        public string? ForgetPassword(string email, string url)
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

        public void ResendEmailVerification(string email, string url)
        {
            var user = GetByEmail(email);

            if (user == null || user.IsEmailVerified)
                return;

            // Generate token
            var token = TokenHelper.GenerateToken();

            user.EmailVerifyCode = token;
            user.EmailVerifyExpire = DateTime.UtcNow.AddMinutes(15);
            user.UpdatedAt = DateTime.UtcNow;

            Uow.UserAccounts.Update(user);
            Uow.Commit();

            // Build reset link
            string resetUrl = $"{url}/verifyemail/{Uri.EscapeDataString(token)}";
            var subject = "Verify your email";

            var model = new WelcomeEmail
            {
                Username = user.Username ?? user.Email,
                LoginUrl = resetUrl
            };

            string mailBody = _emailService.RenderEmailTemplate("~/Views/Register.cshtml", model);

            EmailSetting setting = _emailSettingService.GetSetting();

            Task.Factory.StartNew(() => _emailService.SendEmail(setting, user.Email, subject, mailBody, null), TaskCreationOptions.LongRunning)
                .ContinueWith((t) => { });
        }

        public bool VerifyEmail(string token)
        {
            var user = Uow.UserAccounts
                .Find(u => u.EmailVerifyCode == token && u.EmailVerifyExpire > DateTime.UtcNow)
                .FirstOrDefault();

            if (user == null)
                return false;

            user.IsEmailVerified = true;
            user.EmailVerifyCode = null;
            user.EmailVerifyExpire = null;
            user.UpdatedAt = DateTime.UtcNow;

            Uow.UserAccounts.Update(user);
            Uow.Commit();

            return true;
        }

        //Web method
        public ICollection<UserAccountList> GetListByPayeeId()
        {
            var users = Uow.UserAccounts.Find(e => e.PayeeId == UserContext.EmpId);
            var roles = Uow.UserRoles.GetAll();

            return users.Join(roles,
                    u => u.RoleId,
                    r => r.RoleId,
                    (u, r) => new UserAccountList
                    {
                        UserId = u.UserId,
                        RoleId = u.RoleId,
                        RoleName = r.RoleName,
                        Username = u.Username,
                        Email = u.Email,
                        Phone = u.Phone,
                        IsEmailVerified = u.IsEmailVerified,
                        IsPhoneVerified = u.IsPhoneVerified,
                        Inactive = u.Inactive,
                        CreatedAt = u.CreatedAt
                    })
                .ToList();
        }

        public bool EmailExists(string email, int userId)
        {
            return Uow.UserAccounts.Exists(e =>
                e.Email.ToLower() == email.ToLower() &&
                e.UserId != userId);
        }

        public bool UsernameExists(string username, int userId)
        {
            return Uow.UserAccounts.Exists(e =>
                e.Username.ToLower() == username.ToLower() &&
                e.UserId != userId);
        }

        public bool PhoneExists(string phone, int userId)
        {
            return Uow.UserAccounts.Exists(e =>
                e.Phone != null &&
                e.Phone == phone &&
                e.UserId != userId);
        }

        public UserAccount Create(UserAccount account, string loginUrl)
        {
            var tempPassword = Utilities.GenerateRandomPassword();

            account.PayeeId = UserContext.EmpId;
            account.PasswordHash = Utilities.Encrypt(tempPassword);
            account.IsEmailVerified = true;

            Uow.UserAccounts.Add(account);
            Uow.Commit();

            var model = new WelcomeEmail
            {
                Username = account.Username,
                Email = account.Email,
                TempPassword = tempPassword,
                LoginUrl = loginUrl
            };

            string mailBody = _emailService.RenderEmailTemplate("~/Views/WelcomeEmail.cshtml", model);
            EmailSetting setting = _emailSettingService.GetSetting();

            Task.Factory.StartNew(() => _emailService.SendEmail(setting, account.Email, "Your Account Is Ready", mailBody, null), TaskCreationOptions.LongRunning)
                .ContinueWith((t) => { });

            return account;
        }

        public UserAccount? Update(UserAccount account)
        {
            var existing = GetById(account.UserId);

            if (existing == null)
                return null;

            existing.RoleId = account.RoleId;
            existing.Username = account.Username;
            existing.Phone = account.Phone;
            existing.Inactive = account.Inactive;
            existing.UpdatedAt = DateTime.UtcNow;

            Uow.UserAccounts.Update(existing);
            Uow.Commit();

            return existing;
        }

        public bool Delete(int userId)
        {
            var user = Uow.UserAccounts.Find(e => e.UserId == userId && e.PayeeId == UserContext.EmpId).FirstOrDefault();

            if (user == null)
                return false;

            Uow.UserAccounts.Remove(user);
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

                Uow.UserAccounts.Update(user);
                Uow.Commit();
            }
        }
    }
}
