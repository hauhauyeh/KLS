using KLS.Common;
using KLS.Models;
using KLS.Services;
using KLS.Services.Interfaces;
using System.Text.Json;

namespace KLS.API.Helpers
{
    public class JWTMiddleware
    {
        private readonly RequestDelegate _next;
        private readonly IJWTService _JWTService;

        public JWTMiddleware(RequestDelegate next, IJWTService jWTService)
        {
            _next = next;
            _JWTService = jWTService;
        }

        public async Task Invoke(HttpContext context)
        {
            var token = context.Request.Headers["Authorization"].FirstOrDefault()?.Split(" ").Last();

            if (token != null)
            {
                var userJSON = _JWTService.ValidateJwtToken(token);

                if (!string.IsNullOrEmpty(userJSON))
                {
                    // attach user to context on successful jwt validation
                    //context.Items["User"] = userJSON;

                    var user = JsonSerializer.Deserialize<UserAccount>(userJSON);

                    if (user != null)
                    {
                        context.Items["CurrentUser"] = user;
                        UserContext.EmpId = user.PayeeId;

                        context.Items["RefreshToken"] = user.RefToken;
                        //context.Items["PayeeId"] = user.PayeeId;
                        //context.Items["RoleId"] = user.RoleId;

                        // 🔑 Resolve scoped service correctly
                        var roleService = context.RequestServices.GetRequiredService<IUserRoleService>();
                        var role = roleService.GetById(user.RoleId);

                        if (role != null)
                        {
                            context.Items["AccessPermission"] = role.RoleAccess;
                            context.Items["IsAdmin"] = role.IsAdmin;
                        }
                    }
                }
            }

            await _next(context);
        }
    }
}
