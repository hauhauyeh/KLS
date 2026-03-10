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

        LoginResult RefreshToken(RefreshTokenReq tokenReq);

        string? ForgetPassword(string email, string url);

        bool ResetPassword(ResetPassword resetPassword);
    }
}
