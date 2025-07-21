using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Models;
using KLS.Services.Interfaces;
using Microsoft.AspNetCore.Mvc.RazorPages;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Text.Json;
using System.Threading.Tasks;

namespace KLS.Services
{
    public class UserService : BaseService, IUserService
    {
        private readonly IEmployeeService _employeeService;
        private readonly IJWTService _jWTService;
        private readonly ISystemSettingService _settingService;
        private readonly IUserRoleService _roleService;

        public UserService(IUnitOfWork uow, IJWTService jWTService, IEmployeeService employeeService, ISystemSettingService settingService, IUserRoleService roleService) : base(uow)
        {
            _jWTService = jWTService;
            _employeeService = employeeService;
            _settingService = settingService;
            _roleService = roleService;
        }

        public User? CheckEmpUsername(LoginReq loginReq)
        {
            return Uow.Users
                .Find(e => e.Username == loginReq.Username && !e.Inactive && e.PayeeId.ToString().StartsWith("1"))
                .FirstOrDefault();
        }

        public User GetUserById(int userId)
        {
            return Uow.Users.GetById(userId);
        }

        public bool UserNameExists(string username, int payeeId)
        {
            return Uow.Users.Exists(c => c.Username.ToLower() == username.ToLower() && c.PayeeId != payeeId);
        }

        public void UpdateUser(User user)
        {
            user.UpdatedAt = DateTime.UtcNow;

            Uow.Users.Update(user);
            Uow.Commit();
        }

        public void UpdateToken(User user)
        {
            var existing = GetUserById(user.UserId);

            if (existing != null)
            {
                existing.RefToken = user.RefToken;
                existing.RefTokenExpire = user.RefTokenExpire;

                Uow.Users.Update(existing);
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

            if (emp.IsRestricted)
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

            var token = _jWTService.GenerateJwtToken(user);
            var userRole = _roleService.GetRoleById(user.RoleId);

            return new LoginResult
            {
                Success = true,
                Token = token,
                RefreshToken = refreshToken,
                Username = user.Username,
                IsAdmin = userRole.IsAdmin,
                IsSalesRole = userRole.IsSalesRole,
                EmpId = user.PayeeId,
                EmpSortName = string.IsNullOrEmpty(emp.FirstName) || string.IsNullOrEmpty(emp.LastName)
                    ? ""
                    : emp.FirstName[0].ToString() + emp.LastName[0].ToString()
            };
        }

        public LoginResult RefreshToken(RefreshTokenReq tokenReq)
        {
            var userJson = _jWTService.ValidateExpiredToken(tokenReq.AccessToken);

            if (string.IsNullOrEmpty(userJson))
                return new LoginResult { Success = false, ErrorMessage = "Invalid or expired token." };

            var user = JsonSerializer.Deserialize<User>(userJson);
            if (user == null)
                return new LoginResult { Success = false, ErrorMessage = "User info malformed." };

            var emp = _employeeService.GetById(user.PayeeId);
            
            if (emp == null)
                return new LoginResult { Success = false, ErrorMessage = "User not found." };

            if (user.RefToken != tokenReq.RefreshToken || user.RefTokenExpire <= DateTime.Now)
                return new LoginResult { Success = false, ErrorMessage = "Invalid or expired refresh token." };


            var newToken = _jWTService.GenerateJwtToken(user);

            var role = _roleService.GetRoleById(user.RoleId);

            var sortName = string.IsNullOrEmpty(emp.FirstName) || string.IsNullOrEmpty(emp.LastName)
                   ? ""
                   : emp.FirstName[0].ToString() + emp.LastName[0].ToString();

            return new LoginResult
            {
                Success = true,
                Token = newToken,
                RefreshToken = user.RefToken,
                Username = user.Username,
                IsAdmin = role.IsAdmin,
                IsSalesRole = role?.IsSalesRole ?? false,
                EmpId = user.PayeeId,
                EmpSortName = sortName
            };
        }
    }
}
