using KLS.API.Helpers;
using KLS.Services.Interfaces;
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel.DataAnnotations;

namespace KLS.API.Controllers.Admin
{
    [AuthorizeAdmin]
    [Route("api/admin/[controller]")]
    [Display(Name = "TempPurchase Management", GroupName = "Admin")]
    public class TempPurchasesController : BaseController
    {
        #region --- Member(s) ---

        private readonly ITempPurchaseService _tempPurchaseService;

        #endregion

        #region --- Constructor(s) ---

        public TempPurchasesController(ITempPurchaseService tempPurchaseService)
        {
            _tempPurchaseService = tempPurchaseService;
        }

        #endregion

        #region --- Method(s) ---



        #endregion
    }
}
