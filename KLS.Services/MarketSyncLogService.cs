using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services
{
    public class MarketSyncLogService : BaseService, IMarketSyncLogService
    {
        public MarketSyncLogService(IUnitOfWork uow) : base(uow) { }

        public MarketSyncLog StartLog(int marketAccountId, string syncType)
        {
            var log = new MarketSyncLog { MarketAccountId = marketAccountId, SyncType = syncType };
            Uow.MarketSyncLogs.Add(log);
            Uow.Commit();
            return log;
        }

        public void CompleteLog(int logId, bool success, int processed, int succeeded, int failed, string? error = null)
        {
            var log = Uow.MarketSyncLogs.GetById(logId);
            if (log == null) return;
            log.Success = success;
            log.RecordsProcessed = processed;
            log.RecordsSucceeded = succeeded;
            log.RecordsFailed = failed;
            log.ErrorMessage = error;
            log.FinishedAt = DateTime.UtcNow;
            Uow.MarketSyncLogs.Update(log);
            Uow.Commit();
        }

        public PagingResponse<MarketSyncLogList> GetPagedList(MarketSyncLogListReq req)
        {
            var list = Uow.MarketSyncLogs.GetPagedList(req).ToList();
            var totalRecords = Uow.MarketSyncLogs.Count(req);
            return new PagingResponse<MarketSyncLogList>(totalRecords, req.Pageno, req.Pagesize)
            {
                RowData = list
            };
        }

        public IEnumerable<MarketSyncLog> GetRecent(int marketAccountId, int count = 20)
        {
            return Uow.MarketSyncLogs.Find(l => l.MarketAccountId == marketAccountId)
                .OrderByDescending(l => l.StartedAt).Take(count).ToList();
        }

        public IEnumerable<MarketSyncLog> GetByAccount(int marketAccountId)
        {
            return Uow.MarketSyncLogs.Find(l => l.MarketAccountId == marketAccountId)
                .OrderByDescending(l => l.StartedAt).ToList();
        }
    }
}
