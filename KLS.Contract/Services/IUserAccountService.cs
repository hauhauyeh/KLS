using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Services
{
    public interface IUserAccountService
    {
        UserAccount? GetByEmail(string email);

        LoginResult LoginUser(LoginReq loginReq);

        LoginResult LoginByPayeeId(int payeeId);

        LoginResult RefreshToken(RefreshTokenReq tokenReq);

        void Logout();

        string? ForgetPassword(string email, string url);

        bool ResetPassword(ResetPassword resetPassword);

        void ResendEmailVerification(string email, string url);

        bool VerifyEmail(string token);

        ICollection<UserAccountList> GetListByPayeeId();

        bool UsernameExists(string username, int userId);

        bool EmailExists(string email, int userId);

        bool PhoneExists(string phone, int userId);

        UserAccount Create(UserAccount account, string loginUrl);

        UserAccount? Update(UserAccount account);

        bool Delete(int userId);

        LoginResult SetPasswordFromToken(SetPasswordReq req);
    }
}
