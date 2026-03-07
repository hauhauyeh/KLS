namespace KLS.Models
{
    public class PromotionSummary
    {
        public int PromotionId { get; set; }
        public string? Name { get; set; }
        public string? PromotionType { get; set; }
        public decimal? DiscountValue { get; set; }
    }

    public class PromotionResult
    {
        public decimal Subtotal { get; set; }
        public decimal TotalDiscount { get; set; }
        public decimal FinalTotal => Subtotal - TotalDiscount;
        public bool IsPromoApplied => TotalDiscount > 0 || FreeItemsAdded.Any();
        public List<AppliedPromotionDto> AppliedPromotions { get; set; } = new();
        public List<FreeItemSummary> FreeItemsAdded { get; set; } = new();
    }

    public class AppliedPromotionDto
    {
        public int PromotionId { get; set; }
        public string? Name { get; set; }
        public string? PromotionType { get; set; }
        public decimal DiscountAmount { get; set; }
    }

    public class FreeItemSummary
    {
        public int ItemId { get; set; }
        public string? ItemName { get; set; }
        public decimal Qty { get; set; }
    }
}
