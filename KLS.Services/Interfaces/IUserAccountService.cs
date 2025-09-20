using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services.Interfaces
{
    public interface IUserAccountService
    {
        UserAccount? CheckEmpUsername(LoginReq loginReq);

        UserAccount GetById(int userId);

        UserAccount? GetByEmail(string email);

        bool UserNameExists(string username, int payeeId);

        void UpdateUser(UserAccount user);

        void UpdateToken(UserAccount user);

        LoginResult LoginEmployee(LoginReq loginReq, string ipAddress);

        LoginResult RefreshToken(RefreshTokenReq tokenReq);

        string ForgetPassword(string email, string url);

        bool ResetPassword(ResetPassword resetPassword);
    }
}
