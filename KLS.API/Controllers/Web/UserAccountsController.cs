using KLS.API.Helpers;
using KLS.Common;
using KLS.Contract.Services;
using KLS.Models;
using Microsoft.AspNetCore.Mvc;

namespace KLS.API.Controllers.Web
{
    [AuthorizeWeb]
    [Route("api/web/[controller]")]
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
            var existing = _userAccountService.GetById(account.UserId);
            if (existing == null || existing.PayeeId != UserContext.EmpId)
                return NotFound("User not found.");

            if (account.Inactive && existing.UserId == UserContext.SystemUserId)
                return BadRequest("Cannot deactivate your own account.");

            if (account.Inactive && existing.RoleId == 1)
                return BadRequest("Cannot deactivate the owner account.");

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
            if (userId == UserContext.SystemUserId)
                return BadRequest("Cannot delete your own account.");

            var existing = _userAccountService.GetById(userId);
            if (existing == null || existing.PayeeId != UserContext.EmpId)
                return NotFound("User not found.");

            if (existing.RoleId == 1)
                return BadRequest("Cannot delete the owner account.");

            _userAccountService.Delete(userId);

            return Ok();
        }

        #endregion
    }
}
