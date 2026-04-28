using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Controllers;
using Microsoft.AspNetCore.Mvc.Filters;
using System.Reflection;
using KLS.Models;

namespace KLS.API.Helpers
{
    [AttributeUsage(AttributeTargets.Class | AttributeTargets.Method)]
    public class AuthorizeAdminAttribute : Attribute, IAuthorizationFilter
    {
        public void OnAuthorization(AuthorizationFilterContext context)
        {
            var actionDescriptor = context.ActionDescriptor as ControllerActionDescriptor;
            if (actionDescriptor == null)
            {
                context.Result = new StatusCodeResult(StatusCodes.Status403Forbidden);
                return;
            }

            // Skip authorization if [AllowAnonymous] is applied on action or controller
            if (HasAllowAnonymous(actionDescriptor))
                return;

            var currentUser = context.HttpContext.Items["CurrentUser"] as JWTClaim;
            var refreshToken = context.HttpContext.Items["RefreshToken"]?.ToString();

            if (currentUser == null)
            {
                context.Result = new UnauthorizedResult();
                return;
            }

            var dbRefToken = context.HttpContext.Items["DbRefToken"]?.ToString();
            if (string.IsNullOrWhiteSpace(refreshToken) || refreshToken != dbRefToken)
            {
                context.Result = new JsonResult(new { message = "Session ended. You logged in from another device." })
                {
                    StatusCode = StatusCodes.Status401Unauthorized
                };
                return;
            }

            // Employee-only check
            // Prefer replacing this with a real flag/property if available.
            if (!IsEmployee(currentUser))
            {
                context.Result = new StatusCodeResult(StatusCodes.Status403Forbidden);
                return;
            }

            // Admin bypass
            var isAdmin = TryGetBool(context.HttpContext.Items["IsAdmin"]);
            if (isAdmin)
                return;

            // Permission check only if [PermissionKey] exists on the action
            var permissionKeyAttribute = actionDescriptor.MethodInfo.GetCustomAttribute<PermissionKeyAttribute>();
            if (permissionKeyAttribute == null)
                return;

            var permissionKeys = context.HttpContext.Items["PermissionKeys"] as HashSet<string>;
            if (permissionKeys == null || !permissionKeys.Contains(permissionKeyAttribute.Key))
            {
                context.Result = new StatusCodeResult(StatusCodes.Status403Forbidden);
                return;
            }
        }

        private static bool HasAllowAnonymous(ControllerActionDescriptor actionDescriptor)
        {
            var actionAllowAnonymous = actionDescriptor.MethodInfo.GetCustomAttribute<AllowAnonymousAttribute>();
            if (actionAllowAnonymous != null)
                return true;

            var controllerAllowAnonymous = actionDescriptor.ControllerTypeInfo.GetCustomAttribute<AllowAnonymousAttribute>();
            return controllerAllowAnonymous != null;
        }

        private static bool IsEmployee(JWTClaim currentUser)
        {
            // Temporary legacy rule.
            // Replace with currentUser.IsEmployee or Role/Type check when possible.
            return currentUser.PayeeId.ToString().StartsWith("1");
        }

        private static bool TryGetBool(object? value)
        {
            if (value == null)
                return false;

            if (value is bool boolValue)
                return boolValue;

            return bool.TryParse(value.ToString(), out var parsed) && parsed;
        }
    }
}