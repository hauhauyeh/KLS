using KLS.Contract.Interfaces;
using KLS.Data.DataContext;
using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Data.Repositories
{
    public class MarketOrderRepository : KLSRepository<MarketOrder>, IMarketOrderRepository
    {
        public MarketOrderRepository(KLSDBContext dbContext) : base(dbContext)
        {
        }

        private IQueryable<MarketOrder> BuildQuery(MarketOrderListReq req)
        {
            var query = DbContext.MarketOrders.AsQueryable();

            if (req.MarketAccountId.HasValue && req.MarketAccountId.Value > 0)
                query = query.Where(o => o.MarketAccountId == req.MarketAccountId.Value);

            if (!string.IsNullOrEmpty(req.OrderStatus))
                query = query.Where(o => o.OrderStatus == req.OrderStatus);

            if (req.ImportedToErp.HasValue)
                query = query.Where(o => o.ImportedToErp == req.ImportedToErp.Value);

            if (req.StartDate.HasValue)
                query = query.Where(o => o.OrderDate >= req.StartDate.Value.ToDateTime(TimeOnly.MinValue));

            if (req.EndDate.HasValue)
                query = query.Where(o => o.OrderDate < req.EndDate.Value.ToDateTime(TimeOnly.MinValue).AddDays(1));

            if (!string.IsNullOrEmpty(req.Search))
            {
                var term = req.Search.Trim();
                query = query.Where(o =>
                    (o.ExternalOrderId != null && o.ExternalOrderId.Contains(term)) ||
                    (o.CustomerName != null && o.CustomerName.Contains(term)) ||
                    (o.ShipToCity != null && o.ShipToCity.Contains(term)));
            }

            return query;
        }

        public IQueryable<MarketOrder> GetPagedList(MarketOrderListReq req)
        {
            var query = BuildQuery(req);

            query = req.SortField?.ToLower() switch
            {
                "externalorderid" => req.SortOrder == "desc" ? query.OrderByDescending(o => o.ExternalOrderId) : query.OrderBy(o => o.ExternalOrderId),
                "customername" => req.SortOrder == "desc" ? query.OrderByDescending(o => o.CustomerName) : query.OrderBy(o => o.CustomerName),
                "ordertotal" => req.SortOrder == "desc" ? query.OrderByDescending(o => o.OrderTotal) : query.OrderBy(o => o.OrderTotal),
                "orderstatus" => req.SortOrder == "desc" ? query.OrderByDescending(o => o.OrderStatus) : query.OrderBy(o => o.OrderStatus),
                "orderdate" => req.SortOrder == "desc" ? query.OrderByDescending(o => o.OrderDate) : query.OrderBy(o => o.OrderDate),
                _ => query.OrderByDescending(o => o.OrderDate)
            };

            return query.Skip((req.Pageno - 1) * req.Pagesize).Take(req.Pagesize)
                .Select(o => new MarketOrder
                {
                    MarketOrderId = o.MarketOrderId,
                    MarketAccountId = o.MarketAccountId,
                    ExternalOrderId = o.ExternalOrderId,
                    ExternalOrderNo = o.ExternalOrderNo,
                    OrderDate = o.OrderDate,
                    OrderStatus = o.OrderStatus,
                    CustomerName = o.CustomerName,
                    ShipToCity = o.ShipToCity,
                    ShipToState = o.ShipToState,
                    CurrencyCode = o.CurrencyCode,
                    OrderTotal = o.OrderTotal,
                    ImportedToErp = o.ImportedToErp,
                    ErpSalesId = o.ErpSalesId,
                    TotalItems = o.Items != null ? o.Items.Count : 0,
                    MatchedItems = o.Items != null ? o.Items.Count(i => i.MatchStatus != "unmatched") : 0
                });
        }

        public int Count(MarketOrderListReq req)
        {
            return BuildQuery(req).Count();
        }
    }
}
