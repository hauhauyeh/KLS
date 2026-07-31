using KLS.API.Helpers;
using KLS.Contract.Services;
using KLS.Models.WebClientExperience;
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel;
using System.ComponentModel.DataAnnotations;

namespace KLS.API.Controllers.Admin
{
    [AuthorizeAdmin]
    [Route("api/admin/[controller]")]
    [Display(Name = "Web Client Experience Management", GroupName = "Admin")]
    public class WebClientExperienceController : BaseController
    {
        private readonly IWebClientExperienceService _webClientExperienceService;

        public WebClientExperienceController(IWebClientExperienceService webClientExperienceService)
        {
            _webClientExperienceService = webClientExperienceService;
        }

        [HttpGet("Home")]
        [DisplayName("View Web Home Content")]
        [PermissionKey("Admin.WebContent.List")]
        public IActionResult GetHome()
        {
            return Ok(_webClientExperienceService.GetHomeContent());
        }

        [HttpPut("Home")]
        [DisplayName("Update Web Home Content")]
        [PermissionKey("Admin.WebContent.Update")]
        public IActionResult UpdateHome([FromBody] WebClientHomeContentUpdateReq req)
        {
            return Ok(_webClientExperienceService.UpdateHomeContent(req));
        }
    }
}
