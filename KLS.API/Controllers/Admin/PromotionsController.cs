using KLS.API.Helpers;
using KLS.Contract.Services;
using KLS.Models;
using KLS.Services;
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel;
using System.ComponentModel.DataAnnotations;

namespace KLS.API.Controllers.Admin
{
    //[AuthorizeAdmin]
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

        [HttpGet]
        [DisplayName("List Promotion")]
        public IActionResult List([FromQuery] PromotionListReq promotionListReq)
        {
            return Ok(_promotionService.GetPromotionList(promotionListReq));
        }


        [HttpGet("{id}")]
        public IActionResult GetById(int id)
        {
            return Ok(_promotionService.GetById(id));
        }


        [HttpPost]
        [DisplayName("Create Promotion")]
        public IActionResult CreatePromotion([FromBody] Promotion promotion)
        {
            if (_promotionService.ExistsName(promotion))
                return Conflict("Promotion name already exists");

            return Ok(_promotionService.CreatePromotion(promotion));
        }


        [HttpPut]
        [DisplayName("Update Promotion")]
        public IActionResult UpdatePromotion([FromBody] Promotion promotion)
        {
            if (_promotionService.ExistsName(promotion))
                return Conflict("Promotion name already exists");

            return Ok(_promotionService.UpdatePromotion(promotion));
        }


        [HttpDelete("{id}")]
        [DisplayName("Delete Promotion")]
        public IActionResult DeletePromotion(int id)
        {
            _promotionService.Delete(id);
            return Ok();
        }

        #endregion
    }
}
