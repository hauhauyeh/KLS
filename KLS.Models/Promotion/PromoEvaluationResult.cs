using KLS.Models.PromotionEval;

namespace KLS.Models
{
    /// <summary>
    /// Read-only result shape returned by PromoHelperService.EvaluateCart and TogglePromotion.
    /// Superset of PromotionResult (discount totals + applied list + free items) and
    /// PromotionEvalResponse (BOGO eval results + active toggle links). Admin toggle callers
    /// can read the fields they already consume (AvailablePromotions, ActiveLinks) while
    /// new callers (web portal, pre-checkout preview) read the discount totals.
    /// </summary>
    public class PromoEvaluationResult
    {
        // --- From PromotionResult (discount totals + applied promos + free items) ---

        public decimal Subtotal { get; set; }
        public decimal TotalDiscount { get; set; }
        public decimal FinalTotal => Subtotal - TotalDiscount;
        public bool IsPromoApplied => TotalDiscount > 0 || FreeItemsAdded.Count > 0;
        public List<AppliedPromotionDto> AppliedPromotions { get; set; } = new();
        public List<FreeItemSummary> FreeItemsAdded { get; set; } = new();

        // --- From PromotionEvalResponse (toggleable BOGO offers + active toggle links) ---

        public PromotionEvalResult[] AvailablePromotions { get; set; } = [];
        public PromoLink[] ActiveLinks { get; set; } = [];
    }
}
