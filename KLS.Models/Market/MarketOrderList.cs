using System;
using System.ComponentModel.DataAnnotations;

namespace KLS.Models
{
    public class MarketOrderList
    {
        [Key]
        public int MarketOrderId { get; set; }
        public int MarketAccountId { get; set; }
        public string? SalesChannel { get; set; }
        public string? ExternalOrderId { get; set; }
        public string? ExternalOrderNo { get; set; }
        public DateTime? OrderDate { get; set; }
        public string? OrderStatus { get; set; }
        public string? CustomerName { get; set; }
        public string? ShipToCity { get; set; }
        public string? ShipToState { get; set; }
        public string? CurrencyCode { get; set; }
        public decimal? OrderTotal { get; set; }
        public bool ImportedToErp { get; set; }
        public int? ErpSalesId { get; set; }
        public int TotalItems { get; set; }
        public int MatchedItems { get; set; }
    }
}
