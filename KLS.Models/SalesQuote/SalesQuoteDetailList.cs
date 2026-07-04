using System.ComponentModel.DataAnnotations;

namespace KLS.Models
{
    public class SalesQuoteDetailList
    {
        [Key]
        public int SalesQuoteDetailId { get; set; }
        public int SalesQuoteId { get; set; }
        public int LineId { get; set; }
        public int ItemId { get; set; }
        public int ItemUnitId { get; set; }
        public string? Unit { get; set; }
        public decimal? OrdQty { get; set; }
        public decimal? UnitPrice { get; set; }
        public decimal? ExtTotal { get; set; }
        public decimal? DiscountPercent { get; set; }
        public string? Notes { get; set; }
        public bool IsTaxable { get; set; }
        public string? ItemName { get; set; }
        public string? ItemCode { get; set; }
    }
}
