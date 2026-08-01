using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Models;
using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Security.Policy;
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
        private readonly IEmailService _emailService;
        private readonly IEmailAuditService _emailAuditService;

        public UserAccountService(IUnitOfWork uow,
            IJWTService jWTService,
            IUserRoleService userRoleService,
            IEmailService emailService,
            IEmailAuditService emailAuditService) : base(uow)
        {
            _jWTService = jWTService;
            _userRoleService = userRoleService;
            _emailService = emailService;
            _emailAuditService = emailAuditService;
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

        public WebLoginResult LoginUser(LoginReq loginReq)
        {
            var user = CheckUserUsername(loginReq);

            if (user == null || string.IsNullOrEmpty(user.PasswordHash))
                return new WebLoginResult { Success = false, ErrorMessage = "Email or password is incorrect" };

            if (Utilities.Decrypt(user.PasswordHash) != loginReq.Password)
                return new WebLoginResult { Success = false, ErrorMessage = "Password is incorrect" };

            // EMAIL VERIFICATION CHECK
            if (!user.IsEmailVerified)
            {
                return new WebLoginResult
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
                return new WebLoginResult
                {
                    Success = false,
                    ErrorMessage = "Your account has not been approved yet"
                };
            }

            if (!customer.IsOrderingEnabled)
            {
                return new WebLoginResult
                {
                    Success = false,
                    ErrorMessage = "Your account is not yet enabled to place orders"
                };
            }

            return GenerateLoginResult(user);
        }

        public WebLoginResult LoginByPayeeId(int payeeId)
        {
            var user = Uow.UserAccounts.Find(u => u.PayeeId == payeeId && !u.Inactive).FirstOrDefault();

            if (user == null)
                return new WebLoginResult { Success = false, ErrorMessage = "No web account found for this customer." };

            return GenerateLoginResult(user);
        }

        public WebLoginResult RefreshToken(RefreshTokenReq tokenReq)
        {
            var jwtClaim = _jWTService.ValidateExpiredToken(tokenReq.AccessToken);

            if (jwtClaim == null)
                return new WebLoginResult { Success = false, ErrorMessage = "Invalid or expired token." };

            if (jwtClaim.RefreshToken != tokenReq.RefreshToken || jwtClaim.RefTokenExpire <= DateTime.Now)
                return new WebLoginResult { Success = false, ErrorMessage = "Invalid or expired refresh token." };

            var newToken = _jWTService.GenerateJwtToken(jwtClaim);

            var role = _userRoleService.GetById(jwtClaim.RoleId);
            var customer = Uow.Customers.GetById(jwtClaim.PayeeId);

            return new WebLoginResult
            {
                Success = true,
                Token = newToken,
                RefreshToken = jwtClaim.RefreshToken,
                Username = jwtClaim.Username,
                UserId = jwtClaim.UserId,
                IsOwner = jwtClaim.RoleId == 1,
                IsAdmin = role.IsAdmin,
                PriceShow = customer?.PriceShow ?? "Hide",
                IsEditGuide = customer?.IsEditGuide ?? false,
                IsPromotionEnabled = customer?.IsPromotionEnabled ?? false
            };
        }

        private WebLoginResult GenerateLoginResult(UserAccount user)
        {
            var refreshToken = _jWTService.GenerateRefreshToken();
            user.RefToken = refreshToken;
            user.RefTokenExpire = DateTime.Now.AddDays(_jWTService.RefreshTokenValidity());
            UpdateToken(user);

            var role = _userRoleService.GetById(user.RoleId);
            var customer = Uow.Customers.GetById(user.PayeeId);

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

            return new WebLoginResult
            {
                Success = true,
                Token = token,
                RefreshToken = refreshToken,
                Username = user.Username,
                UserId = user.UserId,
                IsOwner = user.RoleId == 1,
                IsAdmin = role.IsAdmin,
                PriceShow = customer?.PriceShow ?? "Hide",
                IsEditGuide = customer?.IsEditGuide ?? false,
                IsPromotionEnabled = customer?.IsPromotionEnabled ?? false
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
                Greeting = "Customer",
                ResetUrl = resetUrl
            };

            string mailBody = _emailService.RenderEmailTemplate("~/Views/ForgotPassword.cshtml", model);

            _emailAuditService.SendAndLog(new EmailAuditMessage
            {
                To = user.Email,
                Subject = subject,
                HtmlBody = mailBody,
                EmailCategory = EmailAudit.Category.Account,
                EmailType = EmailAudit.EmailType.PasswordReset,
                PayeeId = user.PayeeId,
                RelatedEntityType = EmailAudit.RelatedEntity.UserAccount,
                RelatedEntityId = user.UserId,
                Source = EmailAudit.Source.System
            });

            return resetUrl;
        }

        public bool ResetPassword(ResetPassword resetPassword)
        {
            var user = Uow.UserAccounts.Find(u => u.ResetTokenHash == resetPassword.Token && u.ResetTokenExpire > DateTime.UtcNow).FirstOrDefault();

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

            _emailAuditService.SendAndLog(new EmailAuditMessage
            {
                To = user.Email,
                Subject = subject,
                HtmlBody = mailBody,
                EmailCategory = EmailAudit.Category.Account,
                EmailType = EmailAudit.EmailType.EmailVerification,
                PayeeId = user.PayeeId,
                RelatedEntityType = EmailAudit.RelatedEntity.UserAccount,
                RelatedEntityId = user.UserId,
                Source = EmailAudit.Source.System
            });
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
            var token = TokenHelper.GenerateToken();

            account.PayeeId = UserContext.EmpId;
            account.RoleId = 2;
            account.PasswordHash = Utilities.Encrypt(Utilities.GenerateRandomPassword());
            account.IsEmailVerified = true;
            account.EmailVerifyCode = token;
            account.EmailVerifyExpire = DateTime.UtcNow.AddDays(1);

            Uow.UserAccounts.Add(account);
            Uow.Commit();

            string setPasswordUrl = loginUrl.Replace("/login", $"/setpassword/{Uri.EscapeDataString(token)}");

            var model = new WelcomeEmail
            {
                Username = account.Username,
                Email = account.Email,
                LoginUrl = setPasswordUrl
            };

            string mailBody = _emailService.RenderEmailTemplate("~/Views/WelcomeEmail.cshtml", model);

            _emailAuditService.SendAndLog(new EmailAuditMessage
            {
                To = account.Email,
                Subject = "Your Account Is Ready",
                HtmlBody = mailBody,
                EmailCategory = EmailAudit.Category.Account,
                EmailType = EmailAudit.EmailType.AccountReady,
                PayeeId = account.PayeeId,
                RelatedEntityType = EmailAudit.RelatedEntity.UserAccount,
                RelatedEntityId = account.UserId,
                Source = EmailAudit.Source.Manual,
                RequestedBy = UserContext.SystemUserId
            });

            return account;
        }

        public WebLoginResult SetPasswordFromToken(SetPasswordReq req)
        {
            if (req.Password != req.ConfirmPassword)
                return new WebLoginResult { Success = false, ErrorMessage = "Passwords do not match." };

            var user = Uow.UserAccounts.Find(u => u.EmailVerifyCode != null && u.EmailVerifyCode == req.Token && u.EmailVerifyExpire > DateTime.UtcNow
            ).FirstOrDefault();

            if (user == null)
                return new WebLoginResult { Success = false, ErrorMessage = "Invalid or expired link." };

            user.PasswordHash = Utilities.Encrypt(req.Password);

            if (!user.IsEmailVerified)
                user.IsEmailVerified = true;

            user.EmailVerifyCode = null;
            user.EmailVerifyExpire = null;
            user.UpdatedAt = DateTime.UtcNow;

            Uow.UserAccounts.Update(user);
            Uow.Commit();

            var customer = Uow.Customers.GetById(user.PayeeId);

            if (customer == null || !customer.IsApproved)
            {
                return new WebLoginResult
                {
                    Success = true,
                    ErrorMessage = "Password set successfully. Your account is pending approval."
                };
            }

            return GenerateLoginResult(user);
        }

        public UserAccount? Update(UserAccount account)
        {
            var existing = GetById(account.UserId);

            if (existing == null)
                return null;

            existing.Username = account.Username;
            existing.Phone = account.Phone;
            existing.Inactive = account.Inactive;
            existing.UpdatedAt = DateTime.UtcNow;

            Uow.UserAccounts.Update(existing);
            Uow.Commit();

            return existing;
        }

        public UserAccount? UpdateProfile(int userId, UpdateProfileReq req)
        {
            var existing = GetById(userId);
            if (existing == null) return null;

            existing.Username = req.Username;
            existing.Email = req.Email;
            existing.Phone = req.Phone;
            existing.UpdatedAt = DateTime.UtcNow;

            Uow.UserAccounts.Update(existing);
            Uow.Commit();

            return existing;
        }

        public bool ChangePassword(int userId, string currentPassword, string newPassword)
        {
            var user = GetById(userId);
            if (user == null) return false;

            if (Utilities.Decrypt(user.PasswordHash) != currentPassword)
                return false;

            user.PasswordHash = Utilities.Encrypt(newPassword);
            user.UpdatedAt = DateTime.UtcNow;

            Uow.UserAccounts.Update(user);
            Uow.Commit();
            return true;
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

        public UserAccount CreateForAdmin(UserAccount account)
        {
            var existingAccounts = Uow.UserAccounts.Find(u => u.PayeeId == account.PayeeId).ToList();
            if (!existingAccounts.Any())
                account.RoleId = 1;
            else if (existingAccounts.Any(u => u.RoleId == 1))
                account.RoleId = 2;

            account.IsEmailVerified = true;
            account.CreatedAt = DateTime.UtcNow;

            Uow.UserAccounts.Add(account);
            Uow.Commit();

            return account;
        }

        public UserAccount? UpdateForAdmin(UserAccount account)
        {
            var existing = GetById(account.UserId);

            if (existing == null)
                return null;

            existing.Username = account.Username;
            existing.Email = account.Email;
            existing.Phone = account.Phone;
            existing.Inactive = account.Inactive;

            if (!string.IsNullOrEmpty(account.PasswordHash))
                existing.PasswordHash = account.PasswordHash;

            existing.UpdatedAt = DateTime.UtcNow;

            Uow.UserAccounts.Update(existing);
            Uow.Commit();

            return existing;
        }

        public bool DeleteForAdmin(int userId, int payeeId)
        {
            var user = Uow.UserAccounts.Find(e => e.UserId == userId && e.PayeeId == payeeId).FirstOrDefault();

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
