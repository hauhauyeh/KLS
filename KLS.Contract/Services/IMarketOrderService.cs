using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Services
{
    public interface IMarketOrderService
    {
        IEnumerable<MarketOrder> GetByAccount(int marketAccountId);

        MarketOrder? GetById(int id);

        MarketOrder? GetByExternalId(int marketAccountId, string externalOrderId);

        void MatchSkus(int marketOrderId);

        Task<int> ConvertToSalesAsync(int marketOrderId);
    }
}
