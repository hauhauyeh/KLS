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
    [Display(Name = "Bank Feed Account Management", GroupName = "Accounting")]
    public class BankFeedAccountsController : BaseController
    {
        #region --- Member(s) ---

        private readonly IBankFeedAccountService _bankFeedAccountService;

        #endregion

        #region --- Constructor(s) ---

        public BankFeedAccountsController(IBankFeedAccountService bankFeedAccountService)
        {
            _bankFeedAccountService = bankFeedAccountService;
        }

        #endregion

        #region --- Method(s) ---

        [HttpGet("Selectable")]
        [DisplayName("List Bank Feed Accounts")]
        [PermissionKey("Accounting.BankFeed.List")]
        public IActionResult GetSelectable()
        {
            return Ok(_bankFeedAccountService.GetSelectable());
        }

        [HttpPost]
        [DisplayName("Save Bank Feed Account")]
        [PermissionKey("Accounting.BankFeed.Setup")]
        public IActionResult Save([FromBody] BankFeedAccount account)
        {
            return Ok(_bankFeedAccountService.Save(account));
        }

        #endregion
    }
}
