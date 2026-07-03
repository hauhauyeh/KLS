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
    [Display(Name = "CRM Follow-Ups", GroupName = "CRM")]
    public class CRMFollowUpsController : BaseController
    {
        private readonly ICRMFollowUpService _crmFollowUpService;

        public CRMFollowUpsController(ICRMFollowUpService crmFollowUpService)
        {
            _crmFollowUpService = crmFollowUpService;
        }

        [HttpGet]
        [DisplayName("List Follow-Ups")]
        [PermissionKey("CRM.FollowUp.List")]
        public IActionResult List([FromQuery] CRMFollowUpListReq req)
        {
            return Ok(_crmFollowUpService.GetPagedList(req));
        }

        [HttpGet("by-entity")]
        [DisplayName("List Follow-Ups")]
        [PermissionKey("CRM.FollowUp.List")]
        public IActionResult GetByEntity([FromQuery] int? payeeId, [FromQuery] int? leadId, [FromQuery] int pageNo = 1, [FromQuery] int pageSize = 20)
        {
            if (payeeId.HasValue == leadId.HasValue)
                return BadRequest("Provide exactly one of payeeId or leadId.");

            return Ok(_crmFollowUpService.GetByEntity(payeeId, leadId, pageNo, pageSize));
        }

        [HttpGet("{id}")]
        [PermissionKey("CRM.FollowUp.List")]
        public IActionResult GetById(int id)
        {
            var followUp = _crmFollowUpService.GetById(id);
            if (followUp == null) return NotFound();
            return Ok(followUp);
        }

        [HttpPost]
        [DisplayName("Create Follow-Up")]
        [PermissionKey("CRM.FollowUp.Create")]
        public IActionResult Create([FromBody] CRMFollowUpDTO dto)
        {
            return Ok(_crmFollowUpService.Create(dto));
        }

        [HttpPut]
        [DisplayName("Update Follow-Up")]
        [PermissionKey("CRM.FollowUp.Update")]
        public IActionResult Update([FromBody] CRMFollowUpDTO dto)
        {
            var result = _crmFollowUpService.Update(dto);
            if (result == null) return NotFound();
            return Ok(result);
        }

        [HttpPut("{id}/complete")]
        [DisplayName("Complete Follow-Up")]
        [PermissionKey("CRM.FollowUp.Update")]
        public IActionResult Complete(int id, [FromQuery] int? activityId)
        {
            _crmFollowUpService.Complete(id, activityId);
            return Ok();
        }

        [HttpDelete("{id}")]
        [DisplayName("Delete Follow-Up")]
        [PermissionKey("CRM.FollowUp.Delete")]
        public IActionResult Delete(int id)
        {
            _crmFollowUpService.Delete(id);
            return Ok();
        }

        [HttpGet("overdue-count")]
        [PermissionKey("CRM.FollowUp.List")]
        public IActionResult OverdueCount()
        {
            return Ok(_crmFollowUpService.GetOverdueCount());
        }
    }
}
