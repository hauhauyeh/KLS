using KLS.API.Helpers;
using KLS.Contract.Services;
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel.DataAnnotations;

namespace KLS.API.Controllers.Admin
{
    [AuthorizeAdmin]
    [Route("api/admin/[controller]")]
    [Display(Name = "AccountType Management", GroupName = "Admin")]
    public class AccountTypesController : BaseController
    {
        #region --- Member(s) ---

        private readonly IAccountTypeService _accountTypeService;

        #endregion

        #region --- Constructor(s) ---

        public AccountTypesController(IAccountTypeService chartOfAccountTypeService)
        {
            _accountTypeService = chartOfAccountTypeService;
        }

        #endregion

        #region --- Method(s) ---

        [HttpGet("{id}")]
        public IActionResult GetById(int id)
        {
            return Ok(_accountTypeService.GetById(id));
        }

        #endregion
    }
}
