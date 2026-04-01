using KLS.API.Helpers;
using KLS.Common;
using KLS.Contract.Services;
using Microsoft.AspNetCore.Mvc;

namespace KLS.API.Controllers.Web
{
    [AuthorizeWeb]
    [Route("api/web/[controller]")]
    public class CustomerController : BaseController
    {
        #region --- Member(s) ---

        private readonly ICustomerService _customerService;

        #endregion

        #region --- Constructor(s) ---

        public CustomerController(ICustomerService customerService)
        {
            _customerService = customerService;
        }

        #endregion

        #region --- Method(s) ---

        [HttpGet("Profile")]
        public IActionResult GetProfile()
        {
            var customer = _customerService.GetById(UserContext.EmpId);

            if (customer == null)
                return NotFound();

            var nextShipDate = _customerService.GetNextShipDate(UserContext.EmpId);

            return Ok(new
            {
                customer.PayeeName,
                customer.Address,
                customer.City,
                customer.State,
                customer.ZipCode,
                Email = customer.Email,
                Phone = customer.Phone1,
                NextShipDate = nextShipDate.ToString("yyyy-MM-dd")
            });
        }

        #endregion
    }
}
