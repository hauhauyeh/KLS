using System.ComponentModel.DataAnnotations;

namespace KLS.Models
{
    public class RptMarketOrder
    {
        [Key]
        public int MarketOrderItemId { get; set; }

        public int MarketOrderId { get; set; }

        public string? ExternalOrderNo { get; set; }

        public string? SalesChannel { get; set; }

        public DateOnly OrderDate { get; set; }

        public string? CustomerName { get; set; }

        public string? ShipToCity { get; set; }

        public string? ShipToState { get; set; }

        public string? OrderStatus { get; set; }

        public decimal OrderTotal { get; set; }

        public decimal TaxAmount { get; set; }

        public string? CurrencyCode { get; set; }

        public int TotalItems { get; set; }

        public int MatchedItems { get; set; }

        public bool ImportedToErp { get; set; }

        public int? ErpSalesId { get; set; }

        public string? ExternalSku { get; set; }

        public string? ExternalItemName { get; set; }

        public decimal Qty { get; set; }

        public decimal? UnitPrice { get; set; }

        public decimal? LineTotal { get; set; }

        public string MatchStatus { get; set; } = string.Empty;

        public string? ItemName { get; set; }
    }
}
