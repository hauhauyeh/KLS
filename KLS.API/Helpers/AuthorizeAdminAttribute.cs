using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc.Controllers;
using Microsoft.AspNetCore.Mvc.Filters;
using Microsoft.AspNetCore.Mvc;
using System.Text.Json;
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
            if (context.HttpContext.Items["CurrentUser"] != null)
            {
                var CurrentUser = context.HttpContext.Items["CurrentUser"] as User;
                var refreshToken = context.HttpContext.Items["RefreshToken"]?.ToString();

                if (CurrentUser == null || refreshToken != CurrentUser?.RefToken)
                    context.Result = new UnsupportedMediaTypeResult();

                if (!IsProtectedAction(context))
                    return;

                //only employee can access api
                if (!CurrentUser.PayeeId.ToString().StartsWith('1'))
                    context.Result = new UnsupportedMediaTypeResult();

                var isAdmin = Convert.ToBoolean(context.HttpContext.Items["IsAdmin"]?.ToString());

                if (!isAdmin)
                {
                    var routeValues = context.RouteData.Values;

                    string? controllerName = "";
                    string? actionName = "";

                    if (routeValues.ContainsKey("controller"))
                        controllerName = (string?)routeValues["controller"];

                    if (routeValues.ContainsKey("action"))
                        actionName = (string?)routeValues["action"];

                    string actionId = $"{controllerName}-{actionName}";

                    string? accessPermission = context.HttpContext.Items["AccessPermission"]?.ToString();

                    var permissions = JsonConvert.DeserializeObject<List<ControllerGroup>>(accessPermission);

                    if (permissions == null)
                        context.Result = new UnprocessableEntityResult();
                    else
                    {
                        var isAllow = permissions.SelectMany(g => g.Controllers.SelectMany(c => c.Actions.Where(a => a.Id.ToLower() == actionId.ToLower()))).Any();

                        if (!isAllow)
                            context.Result = new UnprocessableEntityResult();
                    }
                }
            }
            else
            {
                context.Result = new UnauthorizedResult();
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

            var authorizeAttribute = controllerTypeInfo.GetCustomAttribute<AuthorizeAttribute>();
            if (authorizeAttribute != null)
                return true;

            authorizeAttribute = actionMethodInfo.GetCustomAttribute<AuthorizeAttribute>();
            if (authorizeAttribute != null)
                return true;

            return false;
        }
    }
}
