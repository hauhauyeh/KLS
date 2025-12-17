using KLS.API.Helpers;
using KLS.Contract.Services;
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel.DataAnnotations;

namespace KLS.API.Controllers.Admin
{
    [AuthorizeAdmin]
    [Route("api/admin/[controller]")]
    [Display(Name = "PurchaseStages Management", GroupName = "Admin")]
    public class PurchaseStagesController : BaseController
    {
        #region --- Member(s) ---

        private readonly IPurchaseStageService _purchaseStageService;

        #endregion

        #region --- Constructor(s) ---

        public PurchaseStagesController(IPurchaseStageService purchaseStageService)
        {
            _purchaseStageService = purchaseStageService;
        }

        #endregion

        #region --- Method(s) ---

        [HttpGet]
        public IActionResult List()
        {
            return Ok(_purchaseStageService.GetAllPurchaseStages());
        }

        #endregion
    }
}
