using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services.Interfaces
{
    public interface ISystemUserService
    {
        SystemUser? CheckEmpUsername(LoginReq loginReq);

        SystemUser GetById(int userId);

        SystemUser? GetByEmail(string email);

        bool UserNameExists(string username, int payeeId);

        void UpdateUser(SystemUser user);

        void UpdateToken(SystemUser user);

        LoginResult LoginEmployee(LoginReq loginReq, string ipAddress);

        LoginResult RefreshToken(RefreshTokenReq tokenReq);

        string ForgetPassword(string email, string url);

        bool ResetPassword(ResetPassword resetPassword);
    }
}
