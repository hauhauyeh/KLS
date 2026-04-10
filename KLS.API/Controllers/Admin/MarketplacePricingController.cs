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
    [Display(Name = "Marketplace Pricing", GroupName = "Marketplace")]
    public class MarketplacePricingController : MarketplaceBaseController
    {
        public MarketplacePricingController(IMarketplaceServiceFactory factory, IUnitOfWork uow) : base(factory, uow) { }

        [HttpPost("Push/{marketItemMapId}")]
        [DisplayName("Push Price")]
        [PermissionKey("Marketplace.Pricing.Push")]
        public async Task<IActionResult> Push(int marketItemMapId)
        {
            try
            {
                var account = ResolveAccountFromMap(marketItemMapId);
                var service = Factory.GetPricingService(account.MarketType);
                return Ok(await service.PushPriceAsync(marketItemMapId));
            }
            catch (KeyNotFoundException ex) { return NotFound(ex.Message); }
            catch (Exception ex) { return BadRequest(ex.Message); }
        }

        [HttpPost("PushAll/{marketAccountId}")]
        [DisplayName("Push All Prices")]
        [PermissionKey("Marketplace.Pricing.Push")]
        public async Task<IActionResult> PushAll(int marketAccountId)
        {
            try
            {
                var account = ResolveAccount(marketAccountId);
                var service = Factory.GetPricingService(account.MarketType);
                var count = await service.PushAllPricesAsync(marketAccountId);
                return Ok(new { Synced = count });
            }
            catch (KeyNotFoundException ex) { return NotFound(ex.Message); }
            catch (Exception ex) { return BadRequest(ex.Message); }
        }
    }
}
