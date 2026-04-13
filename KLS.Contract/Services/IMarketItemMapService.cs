using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Services
{
    public interface IMarketItemMapService
    {
        IEnumerable<MarketItemMap> GetByAccount(int marketAccountId);

        IEnumerable<MarketItemMap> GetByItemIds(IEnumerable<int> itemIds);

        MarketItemMap? GetById(int id);

        MarketItemMap? GetBySku(int marketAccountId, string externalSku);

        bool SkuExists(int marketAccountId, string externalSku, int excludeId = 0);

        MarketItemMap Save(MarketItemMap map);

        void Delete(int id);

        void UpdateSyncStatus(int id, string status, string? error = null);
    }
}
