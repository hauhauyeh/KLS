namespace KLS.API.Helpers
{
    public sealed class ApiKeyMiddleware
    {
        private readonly RequestDelegate _next;
        private readonly IConfiguration _configuration;

        public ApiKeyMiddleware(RequestDelegate next, IConfiguration configuration)
        {
            _next = next;
            _configuration = configuration;
        }

        public async Task InvokeAsync(HttpContext context)
        {
            var path = context.Request.Path.Value ?? string.Empty;

            if (!path.StartsWith("/api/service/", StringComparison.OrdinalIgnoreCase))
            {
                await _next(context);
                return;
            }

            var expectedKey = _configuration["PrintApiSecurity:ApiKey"];

            if (string.IsNullOrWhiteSpace(expectedKey))
            {
                context.Response.StatusCode = StatusCodes.Status500InternalServerError;
                await context.Response.WriteAsync("API key is not configured.");
                return;
            }

            if (!context.Request.Headers.TryGetValue("x-printapi-key", out var providedKey))
            {
                context.Response.StatusCode = StatusCodes.Status401Unauthorized;
                await context.Response.WriteAsync("Missing API key.");
                return;
            }

            if (!string.Equals(expectedKey, providedKey.ToString(), StringComparison.Ordinal))
            {
                context.Response.StatusCode = StatusCodes.Status401Unauthorized;
                await context.Response.WriteAsync("Invalid API key.");
                return;
            }

            await _next(context);
        }
    }
}
