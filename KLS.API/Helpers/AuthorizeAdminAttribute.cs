using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc.Controllers;
using Microsoft.AspNetCore.Mvc.Filters;
using Microsoft.AspNetCore.Mvc;
using System.Reflection;
using System.ComponentModel;
using Newtonsoft.Json;
using KLS.Models;

namespace KLS.API.Helpers
{
    [AttributeUsage(AttributeTargets.Class | AttributeTargets.Method)]
    public class AuthorizeAdminAttribute : Attribute, IAuthorizationFilter
    {
        public void OnAuthorization(AuthorizationFilterContext context)
        {
            if (context.HttpContext.Items["CurrentUser"] == null)
            {
                context.Result = new UnauthorizedResult();
                return;
            }

            var CurrentUser = context.HttpContext.Items["CurrentUser"] as JWTClaim;
            var refreshToken = context.HttpContext.Items["RefreshToken"]?.ToString();

            if (CurrentUser == null || refreshToken != CurrentUser.RefreshToken)
            {
                context.Result = new UnsupportedMediaTypeResult();
                return;
            }

            if (!IsProtectedAction(context))
                return;

            // only employee can access api
            if (!CurrentUser.PayeeId.ToString().StartsWith('1'))
            {
                context.Result = new UnsupportedMediaTypeResult();
                return;
            }

            var isAdmin = Convert.ToBoolean(context.HttpContext.Items["IsAdmin"]?.ToString());

            if (isAdmin)
                return;

            var routeValues = context.RouteData.Values;

            string? controllerName = "";
            string? actionName = "";

            if (routeValues.ContainsKey("controller"))
                controllerName = (string?)routeValues["controller"];

            if (routeValues.ContainsKey("action"))
                actionName = (string?)routeValues["action"];

            string actionId = $"{controllerName}-{actionName}";

            string? accessPermission = context.HttpContext.Items["AccessPermission"]?.ToString();

            if (string.IsNullOrEmpty(accessPermission))
            {
                context.Result = new UnprocessableEntityResult();
                return;
            }

            var permissions = JsonConvert.DeserializeObject<List<ControllerGroup>>(accessPermission);

            if (permissions == null)
            {
                context.Result = new UnprocessableEntityResult();
                return;
            }

            var isAllow = permissions
                .SelectMany(g => g.Controllers
                    .SelectMany(c => c.Actions
                        .Where(a => a.Id.ToLower() == actionId.ToLower())))
                .Any();

            if (!isAllow)
            {
                context.Result = new UnprocessableEntityResult();
                return;
            }
        }

        public bool IsProtectedAction(AuthorizationFilterContext context)
        {
            //if (context.Filters.Any(item => item is IAllowAnonymousFilter))
            //    return false;

            var controllerActionDescriptor = (ControllerActionDescriptor)context.ActionDescriptor;
            var controllerTypeInfo = controllerActionDescriptor.ControllerTypeInfo;
            var actionMethodInfo = controllerActionDescriptor.MethodInfo;

            var AnonymousAttribute = actionMethodInfo.GetCustomAttribute<AllowAnonymousAttribute>();
            if (AnonymousAttribute != null)
                return false;

            var displayAttribute = actionMethodInfo.GetCustomAttribute<DisplayNameAttribute>();
            if (displayAttribute == null)
                return false;

            var authorizeAttribute = controllerTypeInfo.GetCustomAttribute<AuthorizeAdminAttribute>();
            if (authorizeAttribute != null)
                return true;

            authorizeAttribute = actionMethodInfo.GetCustomAttribute<AuthorizeAdminAttribute>();
            if (authorizeAttribute != null)
                return true;

            return false;
        }
    }
}
