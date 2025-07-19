using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services.Interfaces
{
    public interface IUserService
    {
        User? CheckEmpUsername(LoginReq loginReq);

        User GetUserById(int userId);

        bool UserNameExists(string username, int payeeId);

        void UpdateUser(User user);

        void UpdateToken(User user);

        LoginResult LoginEmployee(LoginReq loginReq, string ipAddress);

        LoginResult RefreshToken(RefreshTokenReq tokenReq);
    }
}
