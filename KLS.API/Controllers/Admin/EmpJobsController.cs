using KLS.API.Helpers;
using KLS.Services.Interfaces;
using Microsoft.AspNetCore.Mvc;

namespace KLS.API.Controllers.Admin
{
    [AuthorizeAdmin]
    [Route("api/admin/[controller]")]
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
