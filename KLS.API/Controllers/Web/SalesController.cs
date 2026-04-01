using KLS.API.Helpers;
using KLS.Contract.Services;
using KLS.Models;
using Microsoft.AspNetCore.Mvc;


namespace KLS.API.Controllers.Web
{
    [AuthorizeAdmin]
    [Route("api/web/[controller]")]
    public class SalesController : BaseController
    {
        #region --- Member(s) ---

        private readonly ICustomerService _customerService;
        private readonly IUserAccountService _userAccountService;

        #endregion

        #region --- Constructor(s) ---

        public SalesController(ICustomerService customerService, IUserAccountService userAccountService)
        {
            _customerService = customerService;
            _userAccountService = userAccountService;
        }

        #endregion

        #region --- Method(s) ---

        [HttpGet]
        public IActionResult List([FromQuery] CustomerListReq customerListReq)
        {
            return Ok(_customerService.GetPagedList(customerListReq));
        }


        [HttpGet("Search")]
        public IActionResult Search([FromQuery] PayeeSearchReq searchReq)
        {
            return Ok(_customerService.Search(searchReq));
        }


        [HttpPost("Login/{payeeId}")]
        public IActionResult Login(int payeeId)
        {
            var result = _userAccountService.LoginByPayeeId(payeeId);

            if (!result.Success)
                return BadRequest(new { result.ErrorMessage });

            return Ok(result);
        }

        #endregion
    }
}
