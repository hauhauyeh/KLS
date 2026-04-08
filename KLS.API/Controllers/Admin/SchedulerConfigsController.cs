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
    [Display(Name = "Scheduler Config Management", GroupName = "Admin")]
    public class SchedulerConfigsController : BaseController
    {
        #region --- Member(s) ---

        private readonly ISchedulerConfigService _schedulerConfigService;

        #endregion

        #region --- Constructor(s) ---

        public SchedulerConfigsController(ISchedulerConfigService schedulerConfigService)
        {
            _schedulerConfigService = schedulerConfigService;
        }

        #endregion

        #region --- Method(s) ---

        [HttpGet]
        [DisplayName("List Scheduler Configs")]
        [PermissionKey("Admin.SchedulerConfig.List")]
        public IActionResult List()
        {
            return Ok(_schedulerConfigService.GetList());
        }

        [HttpGet("{id}")]
        public IActionResult GetById(int id)
        {
            var item = _schedulerConfigService.GetById(id);

            if (item == null)
                return NotFound($"Scheduler config with ID {id} not found.");

            return Ok(item);
        }

        [HttpPut]
        [DisplayName("Update Scheduler Config")]
        [PermissionKey("Admin.SchedulerConfig.Update")]
        public IActionResult Update([FromBody] SchedulerConfig schedulerConfig)
        {
            return Ok(_schedulerConfigService.Update(schedulerConfig));
        }

        #endregion
    }
}
