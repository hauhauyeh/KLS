namespace KLS.Models
{
    public class ItemUnitUpdateReq
    {
        public int ItemUnitId { get; set; }
        public string? Unit { get; set; }
        public decimal? P1 { get; set; }
        public string? Barcode { get; set; }
        public decimal? FactorToBase { get; set; }
        public decimal? PricePercentToBase { get; set; }
        public bool? IsDefaultSalesUnit { get; set; }
        public bool? Inactive { get; set; }
    }
}
