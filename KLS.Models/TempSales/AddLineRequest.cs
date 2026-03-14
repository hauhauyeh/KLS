namespace KLS.Models
{
    public class AddLineRequest
    {
        public int PayeeId { get; set; }
        public int SalesId { get; set; }
        public int? ItemId { get; set; }
        public string? ItemCode { get; set; }
        public decimal Qty { get; set; }
        public decimal? UnitPrice { get; set; }
        public string? Unit { get; set; }
        public string? Notes { get; set; }
    }
}
