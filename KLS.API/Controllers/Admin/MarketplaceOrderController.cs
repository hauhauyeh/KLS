using KLS.API.Helpers;
using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Services.Marketplace.Common;
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel;
using System.ComponentModel.DataAnnotations;

namespace KLS.API.Controllers.Admin
{
    [AuthorizeAdmin]
    [Route("api/admin/[controller]")]
    [Display(Name = "Marketplace Orders", GroupName = "Marketplace")]
    public class MarketplaceOrderController : MarketplaceBaseController
    {
        private readonly IMarketOrderService _orderService;

        public MarketplaceOrderController(IMarketplaceServiceFactory factory, IMarketOrderService orderService, IUnitOfWork uow) : base(factory, uow)
        {
            _orderService = orderService;
        }

        [HttpGet("{marketAccountId}")]
        [DisplayName("List Orders")]
        [PermissionKey("Marketplace.Order.List")]
        public IActionResult List(int marketAccountId)
        {
            return Ok(_orderService.GetByAccount(marketAccountId));
        }

        [HttpGet("Detail/{id}")]
        [PermissionKey("Marketplace.Order.List")]
        public IActionResult GetById(int id)
        {
            var order = _orderService.GetById(id);
            if (order == null) return NotFound();
            return Ok(order);
        }

        [HttpPost("Pull/{marketAccountId}")]
        [DisplayName("Pull Orders")]
        [PermissionKey("Marketplace.Order.Pull")]
        public async Task<IActionResult> Pull(int marketAccountId, DateTime? since = null)
        {
            try
            {
                var account = ResolveAccount(marketAccountId);
                var service = Factory.GetOrderService(account.MarketType);
                var count = await service.PullOrdersAsync(marketAccountId, since);
                return Ok(new { Imported = count });
            }
            catch (KeyNotFoundException ex) { return NotFound(ex.Message); }
            catch (Exception ex) { return BadRequest(ex.Message); }
        }

        [HttpPost("MatchSkus/{marketOrderId}")]
        [PermissionKey("Marketplace.Order.List")]
        public IActionResult MatchSkus(int marketOrderId)
        {
            _orderService.MatchSkus(marketOrderId);
            return Ok();
        }

        [HttpPost("ConvertToSales/{marketOrderId}")]
        [DisplayName("Convert to ERP Sales")]
        [PermissionKey("Marketplace.Order.Convert")]
        public async Task<IActionResult> ConvertToSales(int marketOrderId)
        {
            try
            {
                var salesId = await _orderService.ConvertToSalesAsync(marketOrderId);
                return Ok(new { SalesId = salesId });
            }
            catch (NotImplementedException) { return BadRequest("ConvertToSales not yet implemented"); }
            catch (Exception ex) { return BadRequest(ex.Message); }
        }
    }
}
