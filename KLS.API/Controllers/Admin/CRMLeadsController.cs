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
    [Display(Name = "CRM Leads", GroupName = "CRM")]
    public class CRMLeadsController : BaseController
    {
        private readonly ICRMLeadService _crmLeadService;

        public CRMLeadsController(ICRMLeadService crmLeadService)
        {
            _crmLeadService = crmLeadService;
        }

        [HttpGet]
        [DisplayName("List Leads")]
        [PermissionKey("CRM.Lead.List")]
        public IActionResult List([FromQuery] CRMLeadListReq req)
        {
            return Ok(_crmLeadService.GetPagedList(req));
        }

        [HttpGet("{id}")]
        [PermissionKey("CRM.Lead.List")]
        public IActionResult GetById(int id)
        {
            var lead = _crmLeadService.GetById(id);
            if (lead == null) return NotFound();
            return Ok(lead);
        }

        [HttpPost]
        [DisplayName("Create Lead")]
        [PermissionKey("CRM.Lead.Create")]
        public IActionResult Create([FromBody] CRMLeadDTO dto)
        {
            return Ok(_crmLeadService.Create(dto));
        }

        [HttpPut]
        [DisplayName("Update Lead")]
        [PermissionKey("CRM.Lead.Update")]
        public IActionResult Update([FromBody] CRMLeadDTO dto)
        {
            var result = _crmLeadService.Update(dto);
            if (result == null) return NotFound();
            return Ok(result);
        }

        [HttpDelete("{id}")]
        [DisplayName("Delete Lead")]
        [PermissionKey("CRM.Lead.Delete")]
        public IActionResult Delete(int id)
        {
            _crmLeadService.Delete(id);
            return Ok();
        }

        [HttpPost("{id}/convert")]
        [DisplayName("Convert Lead")]
        [PermissionKey("CRM.Lead.Convert")]
        public IActionResult Convert(int id, [FromQuery] int payeeId)
        {
            _crmLeadService.Convert(id, payeeId);
            return Ok();
        }

        [HttpGet("pipeline-summary")]
        [PermissionKey("CRM.Lead.List")]
        public IActionResult PipelineSummary()
        {
            return Ok(_crmLeadService.GetPipelineSummary());
        }
    }
}
