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
    [Display(Name = "AR Management", GroupName = "Admin")]
    public class ARController : BaseController
    {
        #region --- Member(s) ---

        private readonly IPayeeService _payeeService;

        #endregion

        #region --- Constructor(s) ---

        public ARController(IPayeeService payeeService)
        {
            _payeeService = payeeService;
        }

        #endregion

        #region --- Method(s) ---

        [HttpGet]
        [DisplayName("List AR")]
        public IActionResult List([FromQuery] ARCustomerListReq arListReq)
        {
            return Ok(_payeeService.GetARCustomers(arListReq));
        }

        #endregion
    }
}
