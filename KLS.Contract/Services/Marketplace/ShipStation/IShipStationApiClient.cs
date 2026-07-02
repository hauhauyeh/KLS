using KLS.Models;
using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;

namespace KLS.Contract.Services.Marketplace.ShipStation
{
    public interface IShipStationApiClient
    {
        Task<ShipStationOrdersResponse?> GetOrdersAsync(
            int marketAccountId,
            int page,
            int pageSize,
            DateTime? modifyDateStart,
            DateTime? createDateStart,
            int? storeId,
            string? timeZoneId = null,
            CancellationToken ct = default);

        Task<bool> TestConnectionAsync(int marketAccountId, CancellationToken ct = default);

        Task<ShipStationProduct?> GetProductAsync(int marketAccountId, int productId, CancellationToken ct = default);

        Task<bool> UpdateProductUpcAsync(int marketAccountId, int productId, string upc, CancellationToken ct = default);

        Task<ShipStationOrder?> GetOrderByIdAsync(int marketAccountId, int orderId, CancellationToken ct = default);

        Task<string?> GetByResourceUrlAsync(int marketAccountId, string resourceUrl, CancellationToken ct = default);

        Task<int> SubscribeWebhookAsync(int marketAccountId, string targetUrl, string eventType, int? storeId = null, CancellationToken ct = default);

        Task<bool> UnsubscribeWebhookAsync(int marketAccountId, int webhookId, CancellationToken ct = default);

        Task<List<ShipStationWebhookInfo>> ListWebhooksAsync(int marketAccountId, CancellationToken ct = default);
    }
}
