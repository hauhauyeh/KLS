using KLS.Common;
using System.Runtime.InteropServices;

namespace KLS.API.Helpers
{
    public class UserContextMiddleware
    {
        private readonly RequestDelegate _next;

        public UserContextMiddleware(RequestDelegate next)
        {
            _next = next;
        }

        public async Task Invoke(HttpContext context)
        {
            try
            {
                //var empIdClaim = context.User?.Claims?.FirstOrDefault(c => c.Type == "EmpId");

                //if (empIdClaim != null && int.TryParse(empIdClaim.Value, out var empId))
                //{
                //    UserContext.EmpId = empId;
                //}

                // Determine timezone from context or fallback
                string? timezone = null;

                // 1️⃣ First check if it was already set in HttpContext.Items
                if (context.Items.TryGetValue("Timezone", out var tzItem))
                    timezone = tzItem?.ToString();

                // 2️⃣ Otherwise, optionally check headers (common in APIs)
                if (string.IsNullOrWhiteSpace(timezone))
                    timezone = context.Request.Headers["Timezone"].FirstOrDefault();

                // 3️⃣ Default to U.S. Eastern if still missing
                if (string.IsNullOrWhiteSpace(timezone))
                {
                    timezone = RuntimeInformation.IsOSPlatform(OSPlatform.Windows)
                        ? "Eastern Standard Time"   // Windows ID
                        : "America/New_York";       // IANA ID (Linux)
                }

                // Store in context and UserContext for downstream usage
                UserContext.UserTimezone = timezone;
            }
            catch
            {
                // Optional: log if needed
            }

            try
            {
                await _next(context);
            }
            finally
            {
                // Very important to clear values to avoid leak between requests
                UserContext.Clear();
            }
        }
    }
}
