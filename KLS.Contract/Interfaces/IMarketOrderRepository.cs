using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Interfaces
{
    public interface IMarketOrderRepository : IRepository<MarketOrder>
    {
        IQueryable<MarketOrderList> GetPagedList(MarketOrderListReq req);
        int Count(MarketOrderListReq req);
        int ConvertToSales(int marketAccountId, DateOnly orderDate);
    }
}
