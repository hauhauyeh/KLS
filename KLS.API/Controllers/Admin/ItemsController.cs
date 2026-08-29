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
    [Display(Name = "Product Management", GroupName = "Product")]
    public class ItemsController : BaseController
    {
        #region --- Member(s) ---

        private readonly IItemService _itemService;
        private readonly IItemQuoteService _itemQuoteService;
        private readonly IItemUnitService _itemUnitService;
        private readonly IItemCostImportService _itemCostImportService;

        #endregion

        #region --- Constructor(s) ---

        public ItemsController(
            IItemService itemService,
            IItemQuoteService itemQuoteService,
            IItemUnitService itemUnitService,
            IItemCostImportService itemCostImportService)
        {
            _itemService = itemService;
            _itemQuoteService = itemQuoteService;
            _itemUnitService = itemUnitService;
            _itemCostImportService = itemCostImportService;
        }

        #endregion

        #region --- Import Cost ---

        /// <summary>Step 1. Upload a vendor price file (.csv / .xlsx); rows are matched by unit barcode. Writes nothing.</summary>
        [HttpPost("ImportCostPreview")]
        [DisplayName("Import Cost")]
        [PermissionKey("Product.Item.ImportCost")]
        public IActionResult ImportCostPreview([FromForm] ItemCostImportPreviewReq req)
        {
            return Ok(_itemCostImportService.Preview(req));
        }

        /// <summary>Step 2. Stage pending costs from the file on disk. Live prices change only on apply.</summary>
        [HttpPost("ImportCost")]
        [DisplayName("Import Cost")]
        [PermissionKey("Product.Item.ImportCost")]
        public IActionResult ImportCost([FromBody] ItemCostImportTokenReq req)
        {
            return Ok(_itemCostImportService.Import(req));
        }

        /// <summary>The Pending / Apply card: counts, schedule, last apply, CanApply + reason.</summary>
        [HttpGet("PendingCostStatus")]
        [DisplayName("Import Cost")]
        [PermissionKey("Product.Item.ImportCost")]
        public IActionResult PendingCostStatus()
        {
            return Ok(_itemCostImportService.GetPendingStatus());
        }

        /// <summary>Apply Now. The SP enforces schedule day / once per week / something pending.</summary>
        [HttpPost("ApplyPendingCost")]
        [DisplayName("Apply Pending Cost")]
        [PermissionKey("Product.Item.ApplyCost")]
        public IActionResult ApplyPendingCost()
        {
            return Ok(_itemCostImportService.ApplyPending());
        }

        /// <summary>Reprice Open Orders. Re-prices orders flagged at posting on the price-update day; skipped orders are returned with a reason.</summary>
        [HttpPost("RepriceOpenOrders")]
        [DisplayName("Reprice Open Orders")]
        [PermissionKey("Product.Item.ApplyCost")]
        public IActionResult RepriceOpenOrders()
        {
            return Ok(_itemCostImportService.RepriceOpenOrders());
        }

        #endregion

        #region --- Method(s) ---

        [HttpGet]
        [DisplayName("List Products")]
        [PermissionKey("Product.Item.List")]
        public IActionResult List([FromQuery] ItemListReq itemListReq)
        {
            return Ok(_itemService.GetPagedList(itemListReq));
        }


        [HttpGet("ActiveItems")]
        public IActionResult ActiveItems()
        {
            return Ok(_itemService.ActiveItems());
        }


        [HttpGet("ListActiveForKeybox/{payeeId}")]
        public IActionResult ListActiveForKeybox(int payeeId, [FromQuery] string mode = "customer")
        {
            return Ok(_itemService.GetSearchList(payeeId, mode));
        }


        [HttpGet("{itemId}")]
        public IActionResult GetById(int itemId)
        {
            var item = _itemService.GetById(itemId);

            if (item == null)
                return NotFound($"Product not found.");

            return Ok(item);
        }


        [HttpGet("Search")]
        public IActionResult Search([FromQuery] ItemSearchReq searchReq)
        {
            return Ok(_itemService.Search(searchReq));
        }


        [HttpDelete("{itemId}")]
        [DisplayName("Delete Product")]
        [PermissionKey("Product.Item.Delete")]
        public IActionResult Delete(int itemId)
        {
            _itemService.Delete(itemId);
            return Ok();
        }


        [HttpPut("Inactive/{itemId}")]
        public IActionResult Inactive(int itemId)
        {
            _itemService.Inactive(itemId);
            return Ok();
        }


        [HttpPost]
        [DisplayName("Create/Update Product")]
        [PermissionKey("Product.Item.Save")]
        public IActionResult Save([FromBody] Item item)
        {
            if (_itemService.ItemCodeExists(item))
                return Conflict("Code already exists");

            if (_itemService.ItemNameExists(item))
                return Conflict("Name already exists");

            return Ok(_itemService.Save(item));
        }


        [HttpGet("CalcUnit")]
        public IActionResult CalcUnit([FromQuery] ItemPackingReq packingReq)
        {
            return Ok(_itemService.GetCalcUnit(packingReq));
        }


        [HttpGet("CalcRetailPriceProfit")]
        public IActionResult CalcRetailPriceProfit([FromQuery] ItemCalcRetail calcRetail)
        {
            return Ok(_itemService.CalcRetailPriceProfit(calcRetail));
        }


        [HttpPut("UpdateBaseP1")]
        [DisplayName("Edit P1")]
        [PermissionKey("Product.Item.UpdateBaseP1")]
        public IActionResult UpdateBaseP1([FromBody] ItemUpdateReq updateReq)
        {
            _itemService.UpdateBaseP1(updateReq);
            return Ok();
        }


        [HttpPut("UpdateInventorySettings")]
        [DisplayName("Edit Inventory Settings")]
        [PermissionKey("Product.Item.UpdateInventorySettings")]
        public IActionResult UpdateInventorySettings([FromBody] ItemInventorySettingsReq req)
        {
            _itemService.UpdateInventorySettings(req);
            return Ok();
        }


        [HttpGet("GetTargetPrice/{itemId}")]
        public IActionResult GetTargetPrice(int itemId, [FromQuery] string? filterby)
        {
            return Ok(_itemQuoteService.GetTargetrPrice(itemId, filterby));
        }


        // 2026-06-29: POST (was GET). Switching to Unit view with many loaded items (e.g. 500) put
        // all item IDs in the query string and overflowed the server URL/query-string length limit,
        // failing the call. IDs now travel in the request body. Service/SP unchanged (SP STRING_SPLITs
        // the CSV), so we re-join the list here.
        [HttpPost("GetItemUnitList")]
        public IActionResult GetItemUnitList([FromBody] List<int>? itemIds)
        {
            if (itemIds == null || itemIds.Count == 0)
                return Ok(Array.Empty<ItemUnitListRow>());
            return Ok(_itemUnitService.GetUnitViewList(string.Join(",", itemIds)));
        }


        [HttpPut("UpdateItemUnit")]
        [DisplayName("Edit Item Unit")]
        [PermissionKey("Product.Item.UpdateItemUnit")]
        public IActionResult UpdateItemUnit([FromBody] ItemUnitUpdateReq req)
        {
            return Ok(_itemUnitService.UpdateUnit(req));
        }


        [HttpPost("CreateItemUnit")]
        [DisplayName("Create Item Unit")]
        [PermissionKey("Product.Item.CreateItemUnit")]
        public IActionResult CreateItemUnit([FromBody] CreateItemUnitReq req)
        {
            return Ok(_itemUnitService.CreateUnit(req));
        }


        [HttpDelete("DeleteItemUnit/{itemUnitId}")]
        [DisplayName("Delete Item Unit")]
        [PermissionKey("Product.Item.DeleteItemUnit")]
        public IActionResult DeleteItemUnit(int itemUnitId)
        {
            return Ok(_itemUnitService.DeleteUnit(itemUnitId));
        }


        [HttpGet("GetBaseUnitPricing/{itemId}")]
        public IActionResult GetBaseUnitPricing(int itemId)
        {
            var unit = _itemUnitService.GetBaseUnit(itemId);
            if (unit == null) return NotFound("Base unit not found.");
            return Ok(new { unit.RecentCost, unit.P1 });
        }

        #endregion
    }
}
