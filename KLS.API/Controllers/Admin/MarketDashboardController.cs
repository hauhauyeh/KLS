using KLS.API.Helpers;
using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel;
using System.ComponentModel.DataAnnotations;

namespace KLS.API.Controllers.Admin
{
    [AuthorizeAdmin]
    [ClientFeature("Marketplace")]
    [Route("api/admin/[controller]")]
    [Display(Name = "Marketplace Dashboard", GroupName = "Marketplace")]
    public class MarketDashboardController : BaseController
    {
        private readonly IUnitOfWork _uow;
        private readonly IMarketSyncLogService _syncLogService;

        public MarketDashboardController(IUnitOfWork uow, IMarketSyncLogService syncLogService)
        {
            _uow = uow;
            _syncLogService = syncLogService;
        }

        [HttpGet]
        [DisplayName("Dashboard")]
        [PermissionKey("Marketplace.Account.List")]
        public IActionResult GetDashboard()
        {
            var accounts = _uow.MarketAccounts.GetAll().ToList();
            var maps = _uow.MarketItemMaps.GetAll().ToList();
            var orders = _uow.MarketOrders.GetAll().ToList();

            var today = DateTime.UtcNow.Date;

            var dashboard = new
            {
                Accounts = accounts.Select(a => new
                {
                    a.MarketAccountId,
                    a.AccountName,
                    a.MarketType,
                    a.IsActive,
                    a.LastSyncStatus,
                    a.LastSyncAt
                }),

                ListingSummary = new
                {
                    TotalMapped = maps.Count,
                    Active = maps.Count(m => m.IsActive && m.MappingStatus.Is(MarketMappingStatus.Mapped)),
                    Error = maps.Count(m => m.LastSyncStatus.Is(MarketSyncStatus.Failed)),
                    Inactive = maps.Count(m => !m.IsActive || m.MappingStatus.Is(MarketMappingStatus.Inactive))
                },

                OrderSummary = new
                {
                    TotalOrders = orders.Count,
                    TodayOrders = orders.Count(o => o.OrderDate?.Date == today),
                    Pending = orders.Count(o => o.OrderStatus.Is(MarketInternalOrderStatus.Pending)),
                    NotImported = orders.Count(o => !o.ImportedToErp)
                },

                RecentSyncLogs = _uow.MarketSyncLogs.GetAll()
                    .OrderByDescending(l => l.StartedAt)
                    .Take(10)
                    .Select(l => new
                    {
                        l.MarketSyncLogId,
                        l.MarketAccountId,
                        l.SyncType,
                        l.StartedAt,
                        l.FinishedAt,
                        l.Success,
                        l.RecordsProcessed,
                        l.RecordsSucceeded,
                        l.RecordsFailed,
                        l.ErrorMessage
                    }).ToList()
            };

            return Ok(dashboard);
        }
    }
}
