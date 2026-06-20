using KLS.API.Helpers;
using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Models;
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

        [HttpGet]
        [DisplayName("List Orders")]
        [PermissionKey("Marketplace.Order.List")]
        public IActionResult List([FromQuery] MarketOrderListReq req)
        {
            return Ok(_orderService.GetPagedList(req));
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

        [HttpPost("LinkItem")]
        [PermissionKey("Marketplace.Order.List")]
        public async Task<IActionResult> LinkItem([FromBody] LinkOrderItemReq req)
        {
            await _orderService.LinkOrderItemAsync(req.MarketOrderItemId, req.ItemId, req.ItemUnitId,
                                                    req.BarcodeAction, req.NewBarcode);
            return Ok();
        }

        [HttpPost("ConvertToSales")]
        [DisplayName("Convert to ERP Sales")]
        [PermissionKey("Marketplace.Order.Convert")]
        public IActionResult ConvertToSales([FromBody] ConvertToSalesReq req)
        {
            try
            {
                var salesId = _orderService.ConvertToSales(req.MarketAccountId, req.OrderDate);
                if (salesId == 0) return BadRequest("No convertible orders found for this date");
                return Ok(new { SalesId = salesId });
            }
            catch (Exception ex) { return BadRequest(ex.Message); }
        }
    }
}
