using KLS.API.Helpers;
using KLS.Contract.Services;
using KLS.Models;
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel;
using System.ComponentModel.DataAnnotations;

namespace KLS.API.Controllers.Admin
{
    [AuthorizeAdmin]
    [Route("api/admin/[controller]")]
    [Display(Name = "Marketplace Item Mapping", GroupName = "Marketplace")]
    public class MarketItemMapsController : BaseController
    {
        private readonly IMarketItemMapService _service;

        public MarketItemMapsController(IMarketItemMapService service)
        {
            _service = service;
        }

        [HttpGet]
        [DisplayName("List Mappings")]
        [PermissionKey("Marketplace.ItemMap.List")]
        public IActionResult List(int marketAccountId)
        {
            return Ok(_service.GetByAccount(marketAccountId));
        }

        [HttpPost("ByItemIds")]
        [DisplayName("List Mappings By Items")]
        [PermissionKey("Marketplace.ItemMap.List")]
        public IActionResult GetByItemIds([FromBody] int[] itemIds)
        {
            if (itemIds == null || itemIds.Length == 0) return Ok(Array.Empty<MarketItemMap>());
            return Ok(_service.GetByItemIds(itemIds));
        }

        [HttpGet("{id}")]
        public IActionResult GetById(int id)
        {
            var map = _service.GetById(id);
            if (map == null) return NotFound();
            return Ok(map);
        }

        [HttpPost]
        [DisplayName("Save Mapping")]
        [PermissionKey("Marketplace.ItemMap.Save")]
        public IActionResult Save([FromBody] MarketItemMap map)
        {
            if (!string.IsNullOrEmpty(map.ExternalSku) && _service.SkuExists(map.MarketAccountId, map.ExternalSku, map.MarketItemMapId))
                return Conflict("SKU already mapped for this account");
            return Ok(_service.Save(map));
        }

        [HttpDelete("{id}")]
        [DisplayName("Delete Mapping")]
        [PermissionKey("Marketplace.ItemMap.Delete")]
        public IActionResult Delete(int id)
        {
            _service.Delete(id);
            return Ok();
        }
    }
}
