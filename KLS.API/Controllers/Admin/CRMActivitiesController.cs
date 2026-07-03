using KLS.API.Helpers;
using KLS.Contract.Services;
using KLS.Models;
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel;
using System.ComponentModel.DataAnnotations;

namespace KLS.API.Controllers.Admin
{
    [AuthorizeAdmin]
    [Route("api/admin/[controller]")]
    [Display(Name = "CRM Activities", GroupName = "CRM")]
    public class CRMActivitiesController : BaseController
    {
        private readonly ICRMActivityService _crmActivityService;

        public CRMActivitiesController(ICRMActivityService crmActivityService)
        {
            _crmActivityService = crmActivityService;
        }

        [HttpGet]
        [DisplayName("List Activities")]
        [PermissionKey("CRM.Activity.List")]
        public IActionResult List([FromQuery] int? payeeId, [FromQuery] int? leadId, [FromQuery] int pageNo = 1, [FromQuery] int pageSize = 50)
        {
            return Ok(_crmActivityService.GetByEntity(payeeId, leadId, pageNo, pageSize));
        }

        [HttpPost]
        [DisplayName("Log Activity")]
        [PermissionKey("CRM.Activity.Create")]
        public IActionResult Create([FromBody] CRMActivityDTO dto)
        {
            return Ok(_crmActivityService.Create(dto));
        }

        [HttpDelete("{id}")]
        [DisplayName("Delete Activity")]
        [PermissionKey("CRM.Activity.Delete")]
        public IActionResult Delete(int id)
        {
            _crmActivityService.Delete(id);
            return Ok();
        }
    }
}
