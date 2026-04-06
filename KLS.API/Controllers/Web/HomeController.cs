using KLS.Contract.Services;
using Microsoft.AspNetCore.Mvc;

namespace KLS.API.Controllers.Web
{
    [Route("api/web/[controller]")]
    [ApiController]
    public class HomeController : BaseController
    {
        #region --- Member(s) ---

        private readonly IHomeService _homeService;

        #endregion

        #region --- Constructor(s) ---

        public HomeController(IHomeService homeService)
        {
            _homeService = homeService;
        }

        #endregion

        #region --- Method(s) ---

        [HttpGet]
        public IActionResult GetHomeData()
        {
            var request = HttpContext.Request;
            string baseUrl = $"{request.Scheme}://{request.Host}";

            return Ok(_homeService.GetHomePageData(baseUrl));
        }

        #endregion
    }
}
