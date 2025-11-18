using KLS.API.Helpers;
using KLS.Services.Interfaces;
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel.DataAnnotations;

namespace KLS.API.Controllers.Admin
{
    [AuthorizeAdmin]
    [Route("api/admin/[controller]")]
    [Display(Name = "TempTransferFund Management", GroupName = "Admin")]
    public class TempTransferFundsController : BaseController
    {
        #region --- Member(s) ---

        private readonly ITempTransferFundService _tempTransferFundService;

        #endregion

        #region --- Constructor(s) ---

        public TempTransferFundsController(ITempTransferFundService tempTransferFundService)
        {
            _tempTransferFundService = tempTransferFundService;
        }

        #endregion

        #region --- Method(s) ---



        #endregion
    }
}
