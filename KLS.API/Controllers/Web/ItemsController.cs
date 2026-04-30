using KLS.API.Decorators;
using KLS.API.Helpers;
using KLS.Common;
using KLS.Contract.Services;
using KLS.Models;
using Microsoft.AspNetCore.Mvc;

namespace KLS.API.Controllers.Web
{
    [AuthorizeWeb]
    [Route("api/web/[controller]")]
    public class ItemsController : BaseController
    {
        #region --- Member(s) ---

        private readonly IItemService _itemService;
        private readonly IItemImageService _itemImageService;
        private readonly IItemCategoryService _itemCategoryService;
        private readonly IPromoHelperService _promoHelper;

        #endregion

        #region --- Constructor(s) ---

        public ItemsController(
            IItemService itemService,
            IItemImageService itemImageService,
            IItemCategoryService itemCategoryService,
            IPromoHelperService promoHelper)
        {
            _itemService = itemService;
            _itemImageService = itemImageService;
            _itemCategoryService = itemCategoryService;
            _promoHelper = promoHelper;
        }

        #endregion

        #region --- Method(s) ---

        [HttpGet]
        public IActionResult List([FromQuery] ItemWebListReq webListReq)
        {
            var page = _itemService.GetWebPagedList(webListReq);
            var discountMap = _promoHelper.GetActiveItemDiscounts();
            var offerBadgeMap = _promoHelper.GetActiveItemOfferBadges();

            var ownListItemIds = _promoHelper.GetOwnListItemIds(UserContext.EmpId);
            if (ownListItemIds.Count > 0)
            {
                foreach (var id in ownListItemIds)
                {
                    discountMap.Remove(id);
                    offerBadgeMap.Remove(id);
                }
            }

            page.RowData.ApplyPromoDecoration(discountMap, offerBadgeMap);
            return Ok(page);
        }


        [HttpGet("{itemId}")]
        public IActionResult GetImages(int itemId)
        {
            return Ok(_itemImageService.GetList(itemId));
        }


        [HttpGet("GetCatTree")]
        public IActionResult GetCatTree()
        {
            return Ok(_itemCategoryService.GetWebTree());
        }


        [HttpGet("Search")]
        public IActionResult Search([FromQuery] string term)
        {
            return Ok(_itemService.WebSearch(term));
        }

        #endregion
    }
}
