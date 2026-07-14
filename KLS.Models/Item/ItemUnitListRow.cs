namespace KLS.Models
{
    public class ItemUnitListRow
    {
        public int ItemId { get; set; }
        public string? ItemCode { get; set; }
        public string? ItemName { get; set; }
        public string? ImagePath { get; set; }
        public int ItemUnitId { get; set; }
        public string? Unit { get; set; }
        public bool IsBaseUnit { get; set; }
        public bool IsDefaultSalesUnit { get; set; }
        public decimal? FactorToBase { get; set; }
        // 2026-07-12: ItemUnit_GetViewList projects MultipleToBase; unit view needs it for the multiply/divide ratio badge.
        public int MultipleToBase { get; set; } = 1;
        public decimal? RecentCost { get; set; }
        public decimal? P1 { get; set; }
        public string? Barcode { get; set; }
        public bool Inactive { get; set; }
        public decimal? PricePercentToBase { get; set; }
    }
}
