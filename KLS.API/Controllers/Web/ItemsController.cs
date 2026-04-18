using KLS.API.Helpers;
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

        #endregion

        #region --- Constructor(s) ---

        public ItemsController(IItemService itemService, IItemImageService itemImageService, IItemCategoryService itemCategoryService)
        {
            _itemService = itemService;
            _itemImageService = itemImageService;
            _itemCategoryService = itemCategoryService;
        }

        #endregion

        #region --- Method(s) ---

        [HttpGet]
        public IActionResult List([FromQuery] ItemWebListReq webListReq)
        {
            return Ok(_itemService.GetWebPagedList(webListReq));
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
