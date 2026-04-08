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
                    //UserContext.IsAdmin = jwtClaim.IsAdmin;

                    bool? isAdmin = null;
                    int roleId = 0;

                    if (jwtClaim.Portal == EnumHelper.Portal.Admin.ToString())
                    {
                        var roleService = context.RequestServices.GetRequiredService<ISystemRoleService>();
                        var role = roleService.GetById(jwtClaim.RoleId);

                        if (role != null)
                        {
                            isAdmin = role.IsAdmin;
                            roleId = role.SystemRoleId;
                            UserContext.IsSalesRole = role.IsSalesRole;

                            // New permission system: load permission keys from cache
                            if (!role.IsAdmin)
                            {
                                var permService = context.RequestServices.GetRequiredService<IPermissionService>();
                                var permKeys = permService.GetPermissionKeys(role.SystemRoleId);
                                context.Items["PermissionKeys"] = permKeys;
                            }

                            /* [DEPRECATED-PERMISSION] Old RoleAccess loading — no longer needed.
                               Uncomment to rollback to JSON-based permission checking.
                            accessPermission = role.RoleAccess;
                            */
                        }
                    }
                    else
                    {
                        var roleService = context.RequestServices.GetRequiredService<IUserRoleService>();
                        var role = roleService.GetById(jwtClaim.RoleId);

                        if (role != null)
                        {
                            // Web/Sales portals still use old RoleAccess — not in scope
                            context.Items["AccessPermission"] = role.RoleAccess;
                            isAdmin = role.IsAdmin;
                            roleId = role.RoleId;
                        }
                    }

                    context.Items["IsAdmin"] = isAdmin;
                    context.Items["RoleId"] = roleId.ToString();
                    
                    /* [DEPRECATED-PERMISSION] Old AccessPermission for Admin portal — commented out.
                    if (accessPermission != null)
                    {
                        context.Items["AccessPermission"] = accessPermission;
                    }
                    */
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
