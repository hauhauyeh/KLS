using System.Collections.Generic;

namespace KLS.Models.Cart
{
    public class WebCartItem
    {
        public int TempSalesId { get; set; }
        public int? ItemId { get; set; }
        public string? ItemCode { get; set; }
        public string? ItemName { get; set; }
        public string? PrimaryImageUrl { get; set; }
        public int? ItemUnitId { get; set; }
        public string? Unit { get; set; }
        public decimal? OrdQty { get; set; }
        public decimal? UnitPrice { get; set; }
        public decimal? ExtTotal { get; set; }
    }
}
