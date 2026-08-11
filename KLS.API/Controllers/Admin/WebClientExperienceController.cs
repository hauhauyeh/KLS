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

        [HttpGet("Templates")]
        [DisplayName("List Web Home Templates")]
        [PermissionKey("Admin.WebContent.List")]
        public IActionResult GetTemplates()
        {
            return Ok(_webClientExperienceService.GetTemplates());
        }

        [HttpPost("Templates/ResetDefault")]
        [DisplayName("Reset Web Home Content From Default Template")]
        [PermissionKey("Admin.WebContent.Update")]
        public IActionResult ResetDefaultTemplate()
        {
            return Ok(_webClientExperienceService.ResetHomeContentFromDefaultTemplate());
        }

        [HttpPost("Templates/Load/{templateKey}")]
        [DisplayName("Load Web Home Content From Template")]
        [PermissionKey("Admin.WebContent.Update")]
        public IActionResult LoadTemplate(string templateKey)
        {
            return Ok(_webClientExperienceService.LoadHomeContentFromTemplate(templateKey));
        }

        [HttpPost("Templates/Save/{templateKey}")]
        [DisplayName("Save Web Home Content To Template")]
        [PermissionKey("Admin.WebContent.Update")]
        public IActionResult SaveTemplate(string templateKey, [FromBody] WebClientHomeContentUpdateReq req)
        {
            _webClientExperienceService.UpdateHomeContent(req);
            return Ok(_webClientExperienceService.SaveCurrentProfileToTemplate(templateKey));
        }
    }
}
