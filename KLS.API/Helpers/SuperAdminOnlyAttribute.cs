using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;

namespace KLS.API.Helpers
{
    [AttributeUsage(AttributeTargets.Class | AttributeTargets.Method)]
    public class SuperAdminOnlyAttribute : Attribute, IAuthorizationFilter
    {
        public void OnAuthorization(AuthorizationFilterContext context)
        {
            var isAdmin = context.HttpContext.Items["IsAdmin"];
            bool isSuperAdmin = isAdmin is bool b ? b : (bool.TryParse(isAdmin?.ToString(), out var p) && p);

            if (!isSuperAdmin)
            {
                context.Result = new ObjectResult("Access denied. Super admin only.")
                {
                    StatusCode = StatusCodes.Status403Forbidden
                };
            }
        }
    }
}
