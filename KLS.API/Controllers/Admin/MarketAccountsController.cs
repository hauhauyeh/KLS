using KLS.API.Helpers;
using KLS.Common;
using KLS.Contract.Dtos;
using KLS.Contract.Services;
using KLS.Services.Marketplace.Common;
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel;
using System.ComponentModel.DataAnnotations;

namespace KLS.API.Controllers.Admin
{
    [AuthorizeAdmin]
    [Route("api/admin/[controller]")]
    [Display(Name = "Marketplace Account Management", GroupName = "Marketplace")]
    public class MarketAccountsController : BaseController
    {
        private readonly IMarketAccountService _service;
        private readonly IMarketplaceServiceFactory _marketplaceFactory;

        public MarketAccountsController(IMarketAccountService service, IMarketplaceServiceFactory marketplaceFactory)
        {
            _service = service;
            _marketplaceFactory = marketplaceFactory;
        }

        [HttpGet]
        [DisplayName("List Accounts")]
        [PermissionKey("Marketplace.Account.List")]
        public IActionResult List()
        {
            return Ok(_service.GetAll());
        }

        [HttpGet("Active")]
        public IActionResult Active()
        {
            return Ok(_service.GetActive());
        }

        [HttpGet("{id}")]
        public IActionResult GetById(int id)
        {
            var account = _service.GetById(id);
            if (account == null) return NotFound();
            return Ok(account);
        }

        [HttpPost]
        [DisplayName("Save Account")]
        [PermissionKey("Marketplace.Account.Save")]
        public IActionResult Save([FromBody] MarketAccountSaveReq req)
        {
            if (!MarketTypeNames.IsValid(req.MarketType))
                return BadRequest($"Invalid MarketType: {req.MarketType}");
            if (_service.NameExists(req.AccountName, req.MarketAccountId))
                return Conflict("Account name already exists");
            return Ok(_service.Save(req));
        }

        [HttpDelete("{id}")]
        [DisplayName("Delete Account")]
        [PermissionKey("Marketplace.Account.Delete")]
        public IActionResult Delete(int id)
        {
            _service.Delete(id);
            return Ok();
        }

        [HttpPut("ToggleActive/{id}")]
        [PermissionKey("Marketplace.Account.Save")]
        public IActionResult ToggleActive(int id)
        {
            _service.ToggleActive(id);
            return Ok();
        }

        [HttpPost("TestConnection/{id}")]
        [PermissionKey("Marketplace.Account.Save")]
        public async Task<IActionResult> TestConnection(int id)
        {
            var account = _service.GetById(id);
            if (account == null) return NotFound();
            var service = _marketplaceFactory.GetConnectionService(account.MarketType);
            var result = await service.TestConnectionAsync(id);
            return Ok(new { Connected = result });
        }
    }
}
