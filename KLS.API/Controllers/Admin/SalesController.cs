using KLS.API.Helpers;
using KLS.Services.Interfaces;
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel.DataAnnotations;

namespace KLS.API.Controllers.Admin
{
    [AuthorizeAdmin]
    [Route("api/admin/[controller]")]
    [Display(Name = "Sales Management", GroupName = "Admin")]
    public class SalesController : BaseController
    {
        #region --- Member(s) ---

        private readonly ISalesService _salesService;

        #endregion

        #region --- Constructor(s) ---

        public SalesController(ISalesService salesService)
        {
            _salesService = salesService;
        }

        #endregion

        #region --- Method(s) ---



        #endregion
    }
}
