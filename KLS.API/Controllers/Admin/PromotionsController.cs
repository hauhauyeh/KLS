using KLS.API.Helpers;
using KLS.Contract.Services;
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel.DataAnnotations;

namespace KLS.API.Controllers.Admin
{
    [AuthorizeAdmin]
    [Route("api/admin/[controller]")]
    [Display(Name = "Promotion Management", GroupName = "")]
    public class PromotionsController : BaseController
    {
        #region --- Member(s) ---

        private readonly IPromotionService _promotionService;

        #endregion

        #region --- Constructor(s) ---

        public PromotionsController(IPromotionService promotionService)
        {
            _promotionService = promotionService;
        }

        #endregion

        #region --- Method(s) ---



        #endregion
    }
}
