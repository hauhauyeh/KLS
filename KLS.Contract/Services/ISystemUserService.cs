using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Services
{
    public interface ISystemUserService
    {
        SystemUser? CheckEmpUsername(LoginReq loginReq);

        SystemUser GetById(int userId);

        SystemUser? GetByEmail(string email);

        bool UserNameExists(string username, int payeeId);

        bool EmailExists(string email, int payeeId);

        void UpdateUser(SystemUser user);

        void UpdateToken(SystemUser user);

        LoginResult LoginEmployee(LoginReq loginReq);

        bool VerifyEmployeePermission(LoginReq loginReq, string permissionKey);

        LoginResult RefreshToken(RefreshTokenReq tokenReq);

        string ForgetPassword(string email, string url);

        bool ResetPassword(ResetPassword resetPassword);

        void Logout();
    }
}
