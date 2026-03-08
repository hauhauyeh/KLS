namespace KLS.Models
{
    public class PromotionEvalResult
    {
        public int PromotionId { get; set; }
        public int PromotionBogoId { get; set; }
        public string? DisplayName { get; set; }
        public string? PromotionType { get; set; }
        public bool IsApplicable { get; set; }
        public decimal? PromoPrice { get; set; }
        public decimal? ActualAfterPromo { get; set; }
        public decimal? Savings { get; set; }
        public decimal? ConditionQty { get; set; }
        public decimal? RewardQty { get; set; }
        public List<int> MatchingTempSalesIds { get; set; } = new();
        public string? BadgeText { get; set; }
    }
}
