using KLS.Contract.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;

namespace KLS.API.Helpers
{
    [AttributeUsage(AttributeTargets.Class | AttributeTargets.Method, AllowMultiple = true)]
    public class ClientFeatureAttribute : Attribute, IAuthorizationFilter
    {
        private static readonly Dictionary<string, HashSet<string>> FeatureClients = new(StringComparer.OrdinalIgnoreCase)
        {
            ["Marketplace"] = new HashSet<string>(StringComparer.OrdinalIgnoreCase) { "ABC" }
        };

        private readonly string _feature;

        public ClientFeatureAttribute(string feature)
        {
            _feature = feature;
        }

        public void OnAuthorization(AuthorizationFilterContext context)
        {
            if (!FeatureClients.TryGetValue(_feature, out var allowedClients))
            {
                context.Result = new StatusCodeResult(StatusCodes.Status403Forbidden);
                return;
            }

            var companyService = context.HttpContext.RequestServices.GetRequiredService<ICompanyService>();
            var companyCode = companyService.GetDefault()?.CompanyCode?.Trim();

            if (string.IsNullOrWhiteSpace(companyCode) || !allowedClients.Contains(companyCode))
                context.Result = new StatusCodeResult(StatusCodes.Status403Forbidden);
        }
    }
}
