using KLS.API.Helpers;
using KLS.Services.Interfaces;
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel.DataAnnotations;

namespace KLS.API.Controllers.Timesheets
{
    [Route("api/[controller]")]
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
            return Ok(_empJobService.GetAllJobs());
        }

        #endregion
    }
}
