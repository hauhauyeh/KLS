using KLS.Services.Interfaces;
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel.DataAnnotations;

namespace KLS.API.Controllers.Admin
{
    [Route("api/admin/[controller]")]
    [Display(Name = "Customer Management", GroupName = "Admin")]
    public class CustomersController : BaseController
    {
        #region --- Member(s) ---

        private readonly ICustomerService _customerService;

        #endregion

        #region --- Constructor(s) ---

        public CustomersController(ICustomerService customerService)
        {
            _customerService = customerService;
        }

        #endregion

        #region --- Method(s) ---
        #endregion
    }
}
