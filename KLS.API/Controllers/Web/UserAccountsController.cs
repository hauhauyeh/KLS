using KLS.API.Helpers;
using KLS.Common;
using KLS.Contract.Services;
using KLS.Models;
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel.DataAnnotations;

namespace KLS.API.Controllers.Web
{
    [AuthorizeWeb]
    [Route("api/web/[controller]")]
    [Display(Name = "Employee Management", GroupName = "Web")]
    public class UserAccountsController : BaseController
    {
        #region --- Member(s) ---

        private readonly IUserAccountService _userAccountService;

        #endregion

        #region --- Constructor(s) ---

        public UserAccountsController(IUserAccountService userAccountService)
        {
            _userAccountService = userAccountService;
        }

        #endregion

        #region --- Method(s) ---

        [HttpGet]
        public IActionResult GetList()
        {
            return Ok(_userAccountService.GetListByPayeeId());
        }


        [HttpPost]
        public IActionResult Create([FromBody] UserAccount account)
        {
            if (_userAccountService.EmailExists(account.Email, 0))
                return Conflict("Email already registered.");

            if (_userAccountService.UsernameExists(account.Username, 0))
                return Conflict("Username already registered.");

            if (!string.IsNullOrWhiteSpace(account.Phone) && _userAccountService.PhoneExists(account.Phone, 0))
                return Conflict("Phone number already registered.");

            var headers = Request.Headers;
            var url = headers?["Origin"].FirstOrDefault() ?? headers?["Referer"].FirstOrDefault();

            url = $"{url}/login";

            _userAccountService.Create(account, url);

            return Ok();
        }


        [HttpPut]
        public IActionResult Update([FromBody] UserAccount account)
        {
            if (_userAccountService.UsernameExists(account.Username, account.UserId))
                return Conflict("Username already registered.");

            if (!string.IsNullOrWhiteSpace(account.Phone) && _userAccountService.PhoneExists(account.Phone, account.UserId))
                return Conflict("Phone number already registered.");

            _userAccountService.Update(account);

            return Ok();
        }


        [HttpDelete("{userId}")]
        public IActionResult Delete(int userId)
        {
            if (userId == UserContext.EmpId)
                return BadRequest("You cannot delete your own account.");

            var deleted = _userAccountService.Delete(userId);

            if (!deleted)
                return NotFound("User not found.");

            return Ok();
        }

        #endregion
    }
}
