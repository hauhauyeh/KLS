using KLS.API.Helpers;
using KLS.Contract.Services;
using KLS.Models;
using KLS.Services;
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel;
using System.ComponentModel.DataAnnotations;

namespace KLS.API.Controllers.Admin
{
    [AuthorizeAdmin]
    [Route("api/admin/[controller]")]
    [Display(Name = "Promotion Management", GroupName = "Admin")]
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
            return Ok(_promotionService.GetPagedList(promotionListReq));
        }


        [HttpGet("{promotionId}")]
        public IActionResult GetById(int promotionId)
        {
            return Ok(_promotionService.GetById(promotionId));
        }


        [HttpPost]
        [DisplayName("Create Promotion")]
        public IActionResult Create([FromBody] Promotion promotion)
        {
            if (_promotionService.ExistsName(promotion))
                return Conflict("Promotion name already exists");

            return Ok(_promotionService.Create(promotion));
        }


        [HttpPut]
        [DisplayName("Update Promotion")]
        public IActionResult Update([FromBody] Promotion promotion)
        {
            if (_promotionService.ExistsName(promotion))
                return Conflict("Promotion name already exists");

            return Ok(_promotionService.Update(promotion));
        }


        [HttpDelete("{promotionId}")]
        [DisplayName("Delete Promotion")]
        public IActionResult Delete(int promotionId)
        {
            _promotionService.Delete(promotionId);
            return Ok();
        }


        [HttpGet("GetDefaultTimes")]
        public IActionResult GetDefaultTimes()
        {
            return Ok(_promotionService.GetDefaultTimes());
        }


        [HttpPut("UpdateStatus/{promotionId}")]
        public IActionResult UpdateStatus(int promotionId)
        {
            _promotionService.UpdateStatus(promotionId);
            return Ok();
        }

        #endregion
    }
}
