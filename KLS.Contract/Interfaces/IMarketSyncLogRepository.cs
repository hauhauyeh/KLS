using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Interfaces
{
    public interface IMarketSyncLogRepository : IRepository<MarketSyncLog>
    {
        IQueryable<MarketSyncLogList> GetPagedList(MarketSyncLogListReq req);
        int Count(MarketSyncLogListReq req);
    }
}
