namespace KLS.Models.PromotionEval
{
    public class PromotionEvalResponse
    {
        public PromotionEvalResult[] AvailablePromotions { get; set; } = [];
        public PromoLink[] ActiveLinks { get; set; } = [];
    }

    public class PromotionEvalResult
    {
        public int PromotionId { get; set; }
        public int PromotionBogoId { get; set; }
        public string? DisplayName { get; set; }
        public int ConditionItemId { get; set; }
        public decimal ConditionQty { get; set; }
        public decimal RewardQty { get; set; }
        public decimal? PromoPrice { get; set; }
        public string? BadgeText { get; set; }
        public int[] MatchingTempSalesIds { get; set; } = [];
    }

    public class PromoLink
    {
        public int OwnerTempSalesId { get; set; }
        public int PromoTempSalesId { get; set; }
    }
}
