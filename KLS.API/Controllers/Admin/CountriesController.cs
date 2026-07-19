using KLS.API.Helpers;
using KLS.Contract.Services;
using Microsoft.AspNetCore.Mvc;

namespace KLS.API.Controllers.Admin
{
    [AuthorizeAdmin]
    [Route("api/admin/[controller]")]
    public class CountriesController : BaseController
    {
        private readonly ICountryService _countryService;

        public CountriesController(ICountryService countryService)
        {
            _countryService = countryService;
        }

        [HttpGet]
        public IActionResult List([FromQuery] bool activeOnly = true)
        {
            return Ok(_countryService.GetList(activeOnly));
        }
    }
}
