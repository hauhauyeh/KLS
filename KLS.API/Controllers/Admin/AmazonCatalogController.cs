using KLS.API.Helpers;
using KLS.Services.Marketplace.Amazon;
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel;
using System.ComponentModel.DataAnnotations;

namespace KLS.API.Controllers.Admin
{
    [AuthorizeAdmin]
    [Route("api/admin/[controller]")]
    [Display(Name = "Amazon Catalog Search", GroupName = "Marketplace")]
    public class AmazonCatalogController : BaseController
    {
        private readonly IAmazonCatalogService _catalogService;

        public AmazonCatalogController(IAmazonCatalogService catalogService)
        {
            _catalogService = catalogService;
        }

        [HttpGet("Search")]
        [DisplayName("Search Catalog")]
        [PermissionKey("Marketplace.Catalog.Search")]
        public async Task<IActionResult> Search(int marketAccountId, string keywords)
        {
            if (string.IsNullOrWhiteSpace(keywords)) return BadRequest("Keywords required");
            var result = await _catalogService.SearchAsync(marketAccountId, keywords);
            return Ok(result);
        }

        [HttpGet("Item/{asin}")]
        [PermissionKey("Marketplace.Catalog.Search")]
        public async Task<IActionResult> GetByAsin(int marketAccountId, string asin)
        {
            var result = await _catalogService.GetByAsinAsync(marketAccountId, asin);
            if (result == null) return NotFound();
            return Ok(result);
        }
    }
}
