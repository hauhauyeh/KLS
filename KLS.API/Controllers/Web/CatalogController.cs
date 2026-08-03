using KLS.API.Decorators;
using KLS.Common;
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
            if (!IsPublicCatalogAllowed())
                return NotFound();

            var includePrices = IsPublicPriceAllowed();
            var page = _itemService.GetPublicWebPagedList(webListReq, includePrices);

            if (includePrices)
            {
                var discountMap = _promoHelper.GetActiveItemDiscounts();
                var offerBadgeMap = _promoHelper.GetActiveItemOfferBadges();
                // Decorate each ItemWebUnitList.Price/MarketPrice/Discount with any
                // active item-level promos. B2C: public, catalog-level.
                page.RowData.ApplyPromoDecoration(discountMap, offerBadgeMap, _systemSettingService.GetPriceDecimals());
            }
            else
            {
                StripPublicCatalogPrices(page.RowData);
            }

            return Ok(page);
        }


        [HttpGet("items/{itemId}/images")]
        public IActionResult GetImages(int itemId)
        {
            if (!IsPublicCatalogAllowed())
                return NotFound();

            return Ok(_itemImageService.GetList(itemId));
        }


        [HttpGet("categories")]
        public IActionResult GetCategories()
        {
            if (!IsPublicCatalogAllowed())
                return NotFound();

            return Ok(_itemCategoryService.GetWebTree());
        }


        [HttpGet("search")]
        public IActionResult Search([FromQuery] string term)
        {
            if (!IsPublicCatalogAllowed())
                return NotFound();

            return Ok(_itemService.PublicWebSearch(term));
        }

        private bool IsPublicCatalogAllowed()
        {
            return _portalModeService.IsB2C()
                || _systemSettingService.GetByKey<bool>(GlobalKey.WEB_PUBLIC_PRODUCT_LIST_ENABLE);
        }

        private bool IsPublicPriceAllowed()
        {
            return _portalModeService.IsB2C();
        }

        private static void StripPublicCatalogPrices(IEnumerable<ItemWebList>? items)
        {
            if (items == null)
                return;

            foreach (var item in items)
            {
                item.LCloseQty = null;
                item.ExpiryDate = null;
                item.PromoBadgeText = null;
                item.BogoConditionQty = null;
                item.BogoAfterPromoPrice = null;
                item.BogoSavings = null;

                if (item.ItemUnits == null)
                    continue;

                foreach (var unit in item.ItemUnits)
                {
                    unit.MSRP = null;
                    unit.MarketPrice = null;
                    unit.Price = null;
                    unit.Discount = null;
                }
            }
        }

        #endregion
    }
}
