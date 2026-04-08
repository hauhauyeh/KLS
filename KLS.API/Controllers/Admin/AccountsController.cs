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
    [Display(Name = "Account Management", GroupName = "Accounting")]
    public class AccountsController : BaseController
    {
        #region --- Member(s) ---

        private readonly IAccountService _accountService;
        private readonly IAccountCategoryService _accountCategoryService;

        #endregion

        #region --- Constructor(s) ---

        public AccountsController(IAccountService accountService, IAccountCategoryService accountCategoryService)
        {
            _accountService = accountService;
            _accountCategoryService = accountCategoryService;
        }

        #endregion

        #region --- Method(s) ---

        //[HttpGet("RecursiveTree")]
        [HttpGet]
        [DisplayName("List Accounts")]
        [PermissionKey("Accounting.Account.List")]
        public IActionResult List()
        {
            return Ok(_accountCategoryService.GetRecursiveTree());
        }


        [HttpGet("{id}")]
        public IActionResult GetById(int id)
        {
            return Ok(_accountService.GetById(id));
        }


        [HttpGet("Active")]
        public IActionResult GetActive()
        {
            return Ok(_accountService.GetActive());
        }


        [HttpPost]
        [DisplayName("Create Account")]
        [PermissionKey("Accounting.Account.Create")]
        public IActionResult Create([FromBody] Account account)
        {
            //add @ sign if not exist
            if (account?.AccountCode?[0] != '@')
                account.AccountCode = "@" + account.AccountCode;

            if (_accountService.NameExists(account))
                return Conflict("Name already exists.");

            if (_accountService.CodeExists(account))
                return Conflict("Code already exists");

            return Ok(_accountService.Create(account));
        }


        [HttpPut]
        [DisplayName("Update Account")]
        [PermissionKey("Accounting.Account.Update")]
        public IActionResult Update([FromBody] Account account)
        {
            //add @ sign if not exist
            if (account?.AccountCode?[0] != '@')
                account.AccountCode = "@" + account.AccountCode;

            if (_accountService.NameExists(account))
                return Conflict("Name already exists.");

            if (_accountService.CodeExists(account))
                return Conflict("Code already exists");

            return Ok(_accountService.Update(account));
        }


        [HttpDelete("{id}")]
        [DisplayName("Delete Account")]
        [PermissionKey("Accounting.Account.Delete")]
        public IActionResult Delete(int id)
        {
            _accountService.Delete(id);

            return Ok();
        }


        [HttpGet("Search/{term}")]
        public IActionResult Search(string term)
        {
            return Ok(_accountService.Search(term));
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
