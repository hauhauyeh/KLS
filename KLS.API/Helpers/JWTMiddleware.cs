using KLS.Common;
using KLS.Contract.Services;

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
                var jwtClaim = _JWTService.ValidateJwtToken(token);

                if (jwtClaim != null)
                {
                    // attach user to context on successful jwt validation

                    context.Items["CurrentUser"] = jwtClaim;
                    context.Items["RefreshToken"] = jwtClaim.RefreshToken;
                    UserContext.EmpId = jwtClaim.PayeeId;
                    UserContext.SystemUserId = jwtClaim.UserId;
                    UserContext.IsAdmin = jwtClaim.IsAdmin;

                    // 🔑 Resolve scoped service correctly

                    string? accessPermission = null;
                    bool? isAdmin = null;
                    int roleId = 0;

                    if (jwtClaim.Portal == EnumHelper.Portal.Admin.ToString())
                    {
                        var roleService = context.RequestServices.GetRequiredService<ISystemRoleService>();
                        var role = roleService.GetById(jwtClaim.RoleId);

                        if (role != null)
                        {
                            accessPermission = role.RoleAccess;
                            isAdmin = role.IsAdmin;
                            roleId = role.SystemRoleId;
                        }
                    }
                    else
                    {
                        var roleService = context.RequestServices.GetRequiredService<IUserRoleService>();
                        var role = roleService.GetById(jwtClaim.RoleId);

                        if (role != null)
                        {
                            accessPermission = role.RoleAccess;
                            isAdmin = role.IsAdmin;
                            roleId = role.RoleId;
                        }
                    }

                    context.Items["IsAdmin"] = isAdmin;
                    context.Items["RoleId"] = roleId.ToString();

                    if (accessPermission != null)
                    {
                        context.Items["AccessPermission"] = accessPermission;
                    }
                }
            }
            else //for Timesheet portal
            {
                var empIdHeader = context.Request.Headers["EmpId"].FirstOrDefault();

                if (!string.IsNullOrWhiteSpace(empIdHeader) && int.TryParse(empIdHeader, out var empId))
                {
                    UserContext.EmpId = empId;
                }
                else
                {
                    // Handle missing or invalid EmpId gracefully
                    UserContext.EmpId = 0; // or skip setting if optional
                }
            }

            await _next(context);
        }
    }
}
