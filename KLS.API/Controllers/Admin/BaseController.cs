using Microsoft.AspNetCore.Mvc;

namespace KLS.API.Controllers.Admin
{
    [ApiController]
    public class BaseController : ControllerBase
    {
        protected bool IsCurrentUserAdmin()
        {
            var isAdmin = HttpContext.Items["IsAdmin"];
            if (isAdmin is bool b) return b;
            return bool.TryParse(isAdmin?.ToString(), out var parsed) && parsed;
        }
    }
}
