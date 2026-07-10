using KLS.API.Decorators;
using KLS.Contract.Services;
using KLS.Models;
using Microsoft.AspNetCore.Mvc;

namespace KLS.API.Controllers.Web
{
    [Route("api/web/catalog")]
    [ApiController]
    public class CatalogController : BaseController
    {
        #region --- Member(s) ---

        private readonly IPortalModeService _portalModeService;
        private readonly IItemService _itemService;
        private readonly IItemImageService _itemImageService;
        private readonly IItemCategoryService _itemCategoryService;
        private readonly IPromoHelperService _promoHelper;
        private readonly ISystemSettingService _systemSettingService;

        #endregion

        #region --- Constructor(s) ---

        public CatalogController(
            IPortalModeService portalModeService,
            IItemService itemService,
            IItemImageService itemImageService,
            IItemCategoryService itemCategoryService,
            IPromoHelperService promoHelper,
            ISystemSettingService systemSettingService)
        {
            _portalModeService = portalModeService;
            _itemService = itemService;
            _itemImageService = itemImageService;
            _itemCategoryService = itemCategoryService;
            _promoHelper = promoHelper;
            _systemSettingService = systemSettingService;
        }

        #endregion

        #region --- Method(s) ---

        [HttpGet("items")]
        public IActionResult List([FromQuery] ItemWebListReq webListReq)
        {
            if (!_portalModeService.IsB2C())
                return NotFound();

            var page = _itemService.GetPublicWebPagedList(webListReq);
            var discountMap = _promoHelper.GetActiveItemDiscounts();
            var offerBadgeMap = _promoHelper.GetActiveItemOfferBadges();
            // Decorate each ItemWebUnitList.Price/MarketPrice/Discount with any
            // active item-level promos. B2C: public, catalog-level.
            page.RowData.ApplyPromoDecoration(discountMap, offerBadgeMap, _systemSettingService.GetPriceDecimals());
            return Ok(page);
        }


        [HttpGet("items/{itemId}/images")]
        public IActionResult GetImages(int itemId)
        {
            if (!_portalModeService.IsB2C())
                return NotFound();

            return Ok(_itemImageService.GetList(itemId));
        }


        [HttpGet("categories")]
        public IActionResult GetCategories()
        {
            if (!_portalModeService.IsB2C())
                return NotFound();

            return Ok(_itemCategoryService.GetWebTree());
        }


        [HttpGet("search")]
        public IActionResult Search([FromQuery] string term)
        {
            if (!_portalModeService.IsB2C())
                return NotFound();

            return Ok(_itemService.PublicWebSearch(term));
        }

        #endregion
    }
}
