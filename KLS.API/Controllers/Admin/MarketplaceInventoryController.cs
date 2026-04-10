using KLS.API.Helpers;
using KLS.Contract.Interfaces;
using KLS.Services.Marketplace.Common;
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel;
using System.ComponentModel.DataAnnotations;

namespace KLS.API.Controllers.Admin
{
    [AuthorizeAdmin]
    [Route("api/admin/[controller]")]
    [Display(Name = "Marketplace Inventory", GroupName = "Marketplace")]
    public class MarketplaceInventoryController : MarketplaceBaseController
    {
        public MarketplaceInventoryController(IMarketplaceServiceFactory factory, IUnitOfWork uow) : base(factory, uow) { }

        [HttpPost("Push/{marketItemMapId}")]
        [DisplayName("Push Inventory")]
        [PermissionKey("Marketplace.Inventory.Push")]
        public async Task<IActionResult> Push(int marketItemMapId)
        {
            try
            {
                var account = ResolveAccountFromMap(marketItemMapId);
                var service = Factory.GetInventoryService(account.MarketType);
                return Ok(await service.PushInventoryAsync(marketItemMapId));
            }
            catch (KeyNotFoundException ex) { return NotFound(ex.Message); }
            catch (Exception ex) { return BadRequest(ex.Message); }
        }

        [HttpPost("PushAll/{marketAccountId}")]
        [DisplayName("Push All Inventory")]
        [PermissionKey("Marketplace.Inventory.Push")]
        public async Task<IActionResult> PushAll(int marketAccountId)
        {
            try
            {
                var account = ResolveAccount(marketAccountId);
                var service = Factory.GetInventoryService(account.MarketType);
                var count = await service.PushAllInventoryAsync(marketAccountId);
                return Ok(new { Synced = count });
            }
            catch (KeyNotFoundException ex) { return NotFound(ex.Message); }
            catch (Exception ex) { return BadRequest(ex.Message); }
        }
    }
}
