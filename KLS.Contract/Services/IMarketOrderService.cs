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
        PagingResponse<MarketOrder> GetPagedList(MarketOrderListReq req);

        IEnumerable<MarketOrder> GetByAccount(int marketAccountId);

        MarketOrder? GetById(int id);

        MarketOrder? GetByExternalId(int marketAccountId, string externalOrderId);

        void MatchSkus(int marketOrderId);

        Task LinkOrderItemAsync(int marketOrderItemId, int itemId, int itemUnitId,
            string? barcodeAction = null, string? newBarcode = null);

        int ConvertToSales(int marketAccountId, DateOnly orderDate);

        Task<int> BackfillProductIdsAsync(int marketAccountId, CancellationToken ct = default);
    }
}
