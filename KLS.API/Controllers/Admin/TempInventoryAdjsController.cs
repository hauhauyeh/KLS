using KLS.API.Helpers;
using KLS.Services.Interfaces;
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel.DataAnnotations;

namespace KLS.API.Controllers.Admin
{
    [AuthorizeAdmin]
    [Route("api/admin/[controller]")]
    [Display(Name = "TempInventoryAdj Management", GroupName = "Admin")]
    public class TempInventoryAdjsController : BaseController
    {
        #region --- Member(s) ---

        private readonly ITempInventoryAdjService _tempInventoryAdjService;

        #endregion

        #region --- Constructor(s) ---

        public TempInventoryAdjsController(ITempInventoryAdjService tempInventoryAdjService)
        {
            _tempInventoryAdjService = tempInventoryAdjService;
        }

        #endregion

        #region --- Method(s) ---



        #endregion
    }
}
