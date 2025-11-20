using KLS.API.Helpers;
using KLS.Models;
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

        private readonly IAccountService _accountService;
        private readonly IAccountTypeService _accountTypeService;

        #endregion

        #region --- Constructor(s) ---

        public AccountsController(IAccountService accountService, IAccountTypeService accountTypeService)
        {
            _accountService = accountService;
            _accountTypeService = accountTypeService;
        }

        #endregion

        #region --- Method(s) ---

        [HttpGet]
        [DisplayName("List Accounts")]
        public IActionResult GetAccountsTree()
        {
            return Ok(_accountService.GetAccountsTree());
        }


        [HttpGet("{id}")]
        public IActionResult GetById(int id)
        {
            return Ok(_accountService.GetById(id));
        }


        [HttpPost]
        [DisplayName("Create Account")]
        public IActionResult Create([FromBody] Account chartOfAccount)
        {
            //add @ sign if not exist
            if (chartOfAccount?.AccountCode?[0] != '@')
                chartOfAccount.AccountCode = "@" + chartOfAccount.AccountCode;

            if (_accountService.AcctNameExists(chartOfAccount))
                return Conflict("Name already exists.");

            if (_accountService.AcctCodeExists(chartOfAccount))
                return Conflict("Code already exists");

            var created = _accountService.CreateAccount(chartOfAccount);

            return Ok(created);
        }


        [HttpPut]
        [DisplayName("Update Account")]
        public IActionResult Update([FromBody] Account chartOfAccount)
        {
            //add @ sign if not exist
            if (chartOfAccount?.AccountCode?[0] != '@')
                chartOfAccount.AccountCode = "@" + chartOfAccount.AccountCode;

            if (_accountService.AcctNameExists(chartOfAccount))
                return Conflict("Name already exists.");

            if (_accountService.AcctCodeExists(chartOfAccount))
                return Conflict("Code already exists");

            var created = _accountService.UpdateAccount(chartOfAccount);

            return Ok(created);
        }


        [HttpDelete("{id}")]
        [DisplayName("Delete Account")]
        public IActionResult Delete(int id)
        {
            _accountService.DeleteAccount(id);

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
            return Ok(_accountService.SearchAccount(term));
        }


        [HttpGet("Bank")]
        public IActionResult GetBankAccounts()
        {
            return Ok(_accountService.GetBankAccounts());
        }


        [HttpGet("Cash")]
        public IActionResult GetCashAccounts()
        {
            return Ok(_accountService.GetCashAccounts());
        }


        [HttpGet("BankCash")]
        public IActionResult GetBankCashAccounts()
        {
            return Ok(_accountService.GetBankCashAccounts());
        }


        [HttpGet("BankCashCC")]
        public IActionResult GetBankCashCCAccounts()
        {
            return Ok(_accountService.GetBankCashCCAccounts());
        }


        [HttpGet("GetByPaymentMethod/{method}")]
        public IActionResult GetByPaymentMethod(string method)
        {
            return Ok(_accountService.GetByPaymentMethod(method));
        }


        [HttpGet("ACEAccounts")]
        public IActionResult GetACEAccounts()
        {
            return Ok(_accountService.GetACEAccounts());
        }


        [HttpGet("ExpenseAccounts")]
        public IActionResult GetExpenseAccounts()
        {
            return Ok(_accountService.GetExpenseAccounts());
        }

        #endregion
    }
}
