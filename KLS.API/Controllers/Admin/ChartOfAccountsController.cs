using KLS.Models;
using KLS.Services;
using KLS.Services.Interfaces;
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel;
using System.ComponentModel.DataAnnotations;

namespace KLS.API.Controllers.Admin
{
    //[AuthorizeAdmin]
    [Route("api/admin/[controller]")]
    [Display(Name = "ChartOfAccount Management", GroupName = "Admin")]
    public class ChartOfAccountsController : BaseController
    {
        #region --- Member(s) ---

        private readonly IChartOfAccountService _chartOfAccountService;

        #endregion

        #region --- Constructor(s) ---

        public ChartOfAccountsController(IChartOfAccountService chartOfAccountService)
        {
            _chartOfAccountService = chartOfAccountService;
        }

        #endregion

        #region --- Method(s) ---

        [HttpGet]
        [DisplayName("List Accounts")]
        public IActionResult GetAllChartOfAccounts([FromQuery] PagingRequest request)
        {
            return Ok(_chartOfAccountService.GetAllChartOfAccounts(request));
        }


        [HttpGet("{id}")]
        public IActionResult GetById(int id)
        {
            return Ok(_chartOfAccountService.GetById(id));
        }


        [HttpGet("GetActive")]
        public IActionResult GetActive()
        {
            return Ok(_chartOfAccountService.GetActive());
        }


        [HttpPost]
        [DisplayName("Create Account")]
        public IActionResult CreateAccount([FromBody] ChartOfAccount chartOfAccount)
        {
            //add @ sign if not exist
            if (chartOfAccount.AccountCode[0] != '@')
                chartOfAccount.AccountCode = "@" + chartOfAccount.AccountCode;

            if (_chartOfAccountService.NameExists(chartOfAccount))
                return Conflict("Name already exists.");

            if (_chartOfAccountService.AcctCodeExists(chartOfAccount))
                return Conflict("Code already exists");

            var created = _chartOfAccountService.CreateAccount(chartOfAccount);

            return Ok(created);
        }


        [HttpPut]
        [DisplayName("Update Account")]
        public IActionResult UpdateAccount([FromBody] ChartOfAccount chartOfAccount)
        {
            //add @ sign if not exist
            if (chartOfAccount.AccountCode[0] != '@')
                chartOfAccount.AccountCode = "@" + chartOfAccount.AccountCode;

            if (_chartOfAccountService.NameExists(chartOfAccount))
                return Conflict("Name already exists.");

            if (_chartOfAccountService.AcctCodeExists(chartOfAccount))
                return Conflict("Code already exists");

            var created = _chartOfAccountService.UpdateAccount(chartOfAccount);

            return Ok(created);
        }


        [HttpDelete("{id}")]
        [DisplayName("Delete Account")]
        public IActionResult DeleteAccount(int id)
        {
            _chartOfAccountService.DeleteAccount(id);

            return Ok();
        }

        #endregion
    }
}
