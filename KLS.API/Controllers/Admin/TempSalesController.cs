using KLS.API.Helpers;
using KLS.Services.Interfaces;
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel.DataAnnotations;

namespace KLS.API.Controllers.Admin
{
    [AuthorizeAdmin]
    [Route("api/admin/[controller]")]
    [Display(Name = "Temp Order Management", GroupName = "Customer")]
    public class TempSalesController : BaseController
    {
        #region --- Member(s) ---

        private readonly ITempSalesService _tempSalesService;

        #endregion

        #region --- Constructor(s) ---

        public TempSalesController(ITempSalesService tempSalesService)
        {
            _tempSalesService = tempSalesService;
        }

        #endregion

        #region --- Method(s) ---



        #endregion
    }
}
