using KLS.API.Helpers;
using KLS.Contract.Services;
using KLS.Models;
using KLS.Models.PromotionEval;
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
        // Phase 2: unified promo service. Replaced IPromotionEvaluationService DI;
        // EvaluateCart and TogglePromotion signatures are preserved via request overloads.
        private readonly IPromoHelperService _promoService;

        #endregion

        #region --- Constructor(s) ---

        public TempSalesController(ITempSalesService tempSalesService, IPromoHelperService promoService)
        {
            _tempSalesService = tempSalesService;
            _promoService = promoService;
        }

        #endregion

        #region --- Method(s) ---

        [HttpGet]
        public IActionResult List([FromQuery] TempSalesReq tempReq)
        {
            return Ok(_tempSalesService.GetList(tempReq));
        }


        [HttpPost]
        public IActionResult Create([FromBody] TempSalesItem tempItem)
        {
            var result = _tempSalesService.Create(tempItem);
            _promoService.ApplyItemLevelDiscounts(result.SalesId, result.PayeeId);
            return Ok(result);
        }


        [HttpPut]
        public IActionResult Update([FromBody] TempSalesItem tempItem)
        {
            var result = _tempSalesService.Update(tempItem);
            _promoService.ApplyItemLevelDiscounts(result.SalesId, result.PayeeId);
            return Ok(result);
        }


        [HttpPut("UpdateParentSalesNumber")]
        public IActionResult UpdateParentSalesNumber([FromBody] TempSalesParentUpdateReq req)
        {
            return Ok(_tempSalesService.UpdateParentSalesNumber(req));
        }


        [HttpPut("UpdateUnit")]
        public IActionResult UpdateUnit([FromBody] TempSalesItem tempItem)
        {
            var result = _tempSalesService.UpdateUnit(tempItem);
            _promoService.ApplyItemLevelDiscounts(result.SalesId, result.PayeeId);
            return Ok(result);
        }


        [HttpDelete("{tempId}")]
        public IActionResult Delete(int tempId)
        {
            var temp = _tempSalesService.GetById(tempId);
            _tempSalesService.Delete(tempId);
            if (temp != null)
                _promoService.ApplyItemLevelDiscounts(temp.SalesId, temp.PayeeId);
            return Ok();
        }


        [HttpPost("Clear")]
        public IActionResult Clear([FromBody] TempSalesReq tempReq)
        {
            _tempSalesService.Clear(tempReq);
            return Ok();
        }


        [HttpGet("DraftCustomers")]
        public IActionResult DraftCustomers()
        {
            return Ok(_tempSalesService.DraftCustomers());
        }


        [HttpGet("Search")]
        public IActionResult Search([FromQuery] TempSalesReq tempReq)
        {
            return Ok(_tempSalesService.Search(tempReq));
        }


        [HttpPost("AddLine")]
        public IActionResult AddLine([FromBody] AddLineRequest req)
        {
            var result = _tempSalesService.AddLine(req);
            if (result != null)
                _promoService.ApplyItemLevelDiscounts(req.SalesId, req.PayeeId);
            return Ok(result);
        }


        [HttpPost("EvaluatePromotions")]
        public IActionResult EvaluatePromotions([FromBody] PromotionEvalRequest request)
        {
            return Ok(_promoService.EvaluateCart(request));
        }


        [HttpPost("TogglePromotion")]
        public IActionResult TogglePromotion([FromBody] PromoToggleRequest request)
        {
            return Ok(_promoService.TogglePromotion(request));
        }

        #endregion
    }
}
