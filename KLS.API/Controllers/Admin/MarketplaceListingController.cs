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
    [Display(Name = "Marketplace Listing Management", GroupName = "Marketplace")]
    public class MarketplaceListingController : MarketplaceBaseController
    {
        public MarketplaceListingController(IMarketplaceServiceFactory factory, IUnitOfWork uow) : base(factory, uow) { }

        [HttpPost("Push/{marketItemMapId}")]
        [DisplayName("Push Listing")]
        [PermissionKey("Marketplace.Listing.Push")]
        public async Task<IActionResult> Push(int marketItemMapId)
        {
            try
            {
                var account = ResolveAccountFromMap(marketItemMapId);
                var service = Factory.GetListingService(account.MarketType);
                return Ok(await service.PushListingAsync(marketItemMapId));
            }
            catch (KeyNotFoundException ex) { return NotFound(ex.Message); }
            catch (Exception ex) { return BadRequest(ex.Message); }
        }

        [HttpPost("PushAll/{marketAccountId}")]
        [DisplayName("Push All Listings")]
        [PermissionKey("Marketplace.Listing.Push")]
        public async Task<IActionResult> PushAll(int marketAccountId)
        {
            try
            {
                var account = ResolveAccount(marketAccountId);
                var service = Factory.GetListingService(account.MarketType);
                var count = await service.PushAllAsync(marketAccountId);
                return Ok(new { Synced = count });
            }
            catch (KeyNotFoundException ex) { return NotFound(ex.Message); }
            catch (Exception ex) { return BadRequest(ex.Message); }
        }

        [HttpPost("RefreshStatus/{marketItemMapId}")]
        [PermissionKey("Marketplace.Listing.List")]
        public async Task<IActionResult> RefreshStatus(int marketItemMapId)
        {
            try
            {
                var account = ResolveAccountFromMap(marketItemMapId);
                var service = Factory.GetListingService(account.MarketType);
                await service.RefreshStatusAsync(marketItemMapId);
                return Ok();
            }
            catch (KeyNotFoundException ex) { return NotFound(ex.Message); }
            catch (Exception ex) { return BadRequest(ex.Message); }
        }

        [HttpDelete("{marketItemMapId}")]
        [DisplayName("Delete Listing")]
        [PermissionKey("Marketplace.Listing.Delete")]
        public async Task<IActionResult> Delete(int marketItemMapId)
        {
            try
            {
                var account = ResolveAccountFromMap(marketItemMapId);
                var service = Factory.GetListingService(account.MarketType);
                return Ok(await service.DeleteListingAsync(marketItemMapId));
            }
            catch (KeyNotFoundException ex) { return NotFound(ex.Message); }
            catch (Exception ex) { return BadRequest(ex.Message); }
        }
    }
}
