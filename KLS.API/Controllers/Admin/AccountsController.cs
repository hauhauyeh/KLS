using KLS.API.Helpers;
using KLS.Models;
using KLS.Services;
using KLS.Services.Interfaces;
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel;
using System.ComponentModel.DataAnnotations;

namespace KLS.API.Controllers.Admin
{
    [AuthorizeAdmin]
    [Route("api/admin/[controller]")]
    [Display(Name = "Account Management", GroupName = "Admin")]
    public class AccountsController : BaseController
    {
        #region --- Member(s) ---

        private readonly IAccountService _chartOfAccountService;
        private readonly IAccountTypeService _accountTypeService;

        #endregion

        #region --- Constructor(s) ---

        public AccountsController(IAccountService chartOfAccountService, IAccountTypeService accountTypeService)
        {
            _chartOfAccountService = chartOfAccountService;
            _accountTypeService = accountTypeService;
        }

        #endregion

        #region --- Method(s) ---

        [HttpGet]
        [DisplayName("List Accounts")]
        public IActionResult GetAccountsTree()
        {
            return Ok(_chartOfAccountService.GetAccountsTree());
        }


        [HttpGet("{id}")]
        public IActionResult GetById(int id)
        {
            return Ok(_chartOfAccountService.GetById(id));
        }


        [HttpPost]
        [DisplayName("Create Account")]
        public IActionResult Create([FromBody] Account chartOfAccount)
        {
            //add @ sign if not exist
            if (chartOfAccount?.AccountCode?[0] != '@')
                chartOfAccount.AccountCode = "@" + chartOfAccount.AccountCode;

            if (_chartOfAccountService.AcctNameExists(chartOfAccount))
                return Conflict("Name already exists.");

            if (_chartOfAccountService.AcctCodeExists(chartOfAccount))
                return Conflict("Code already exists");

            var created = _chartOfAccountService.CreateAccount(chartOfAccount);

            return Ok(created);
        }


        [HttpPut]
        [DisplayName("Update Account")]
        public IActionResult Update([FromBody] Account chartOfAccount)
        {
            //add @ sign if not exist
            if (chartOfAccount?.AccountCode?[0] != '@')
                chartOfAccount.AccountCode = "@" + chartOfAccount.AccountCode;

            if (_chartOfAccountService.AcctNameExists(chartOfAccount))
                return Conflict("Name already exists.");

            if (_chartOfAccountService.AcctCodeExists(chartOfAccount))
                return Conflict("Code already exists");

            var created = _chartOfAccountService.UpdateAccount(chartOfAccount);

            return Ok(created);
        }


        [HttpDelete("{id}")]
        [DisplayName("Delete Account")]
        public IActionResult Delete(int id)
        {
            _chartOfAccountService.DeleteAccount(id);

            return Ok();
        }


        [HttpGet("AccountTypes")]
        public IActionResult GetAllAccountTypes()
        {
            return Ok(_accountTypeService.GetAllAccountTypes());
        }


        [HttpGet("Search/{term}")]
        public IActionResult SearchAccount(string term)
        {
            return Ok(_chartOfAccountService.SearchAccount(term));
        }


        [HttpGet("Bank")]
        public IActionResult GetBankAccounts()
        {
            return Ok(_chartOfAccountService.GetBankAccounts());
        }


        [HttpGet("BankCash")]
        public IActionResult GetBankCashAccounts()
        {
            return Ok(_chartOfAccountService.GetBankCashAccounts());
        }


        [HttpGet("BankCashCC")]
        public IActionResult GetBankCashCCAccounts()
        {
            return Ok(_chartOfAccountService.GetBankCashCCAccounts());
        }


        [HttpGet("GetByPaymentMethod/{method}")]
        public IActionResult GetByPaymentMethod(string method)
        {
            return Ok(_chartOfAccountService.GetByPaymentMethod(method));
        }


        [HttpGet("ACEAccounts")]
        public IActionResult GetACEAccounts()
        {
            return Ok(_chartOfAccountService.GetACEAccounts());
        }


        [HttpGet("ExpenseAccounts")]
        public IActionResult GetExpenseAccounts()
        {
            return Ok(_chartOfAccountService.GetExpenseAccounts());
        }

        #endregion
    }
}
