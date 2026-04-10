using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Services
{
    public interface IMarketSyncLogService
    {
        MarketSyncLog StartLog(int marketAccountId, string syncType);

        void CompleteLog(int logId, bool success, int processed, int succeeded, int failed, string? error = null);

        IEnumerable<MarketSyncLog> GetRecent(int marketAccountId, int count = 20);

        IEnumerable<MarketSyncLog> GetByAccount(int marketAccountId);
    }
}
