using KLS.Common;

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
                var empIdClaim = context.User?.Claims?.FirstOrDefault(c => c.Type == "EmpId");

                if (empIdClaim != null && int.TryParse(empIdClaim.Value, out var empId))
                {
                    UserContext.EmpId = empId;
                }

                // Example: get from header or context item
                if (context.Items.TryGetValue("Timezone", out var timezone))
                {
                    UserContext.UserTimezone = timezone?.ToString();
                }
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
