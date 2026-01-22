using KLS.Contract.Services;
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel.DataAnnotations;

namespace KLS.API.Controllers.Timesheet
{
    [Route("api/timesheet/[controller]")]
    [Display(Name = "EmpJobs Management", GroupName = "Admin")]
    public class EmpJobsController : BaseController
    {
        #region --- Member(s) ---

        private readonly IEmpJobService _empJobService;

        #endregion

        #region --- Constructor(s) ---

        public EmpJobsController(IEmpJobService empJobService)
        {
            _empJobService = empJobService;
        }

        #endregion

        #region --- Method(s) ---

        [HttpGet]
        public IActionResult List()
        {
            return Ok(_empJobService.GetList());
        }

        #endregion
    }
}
