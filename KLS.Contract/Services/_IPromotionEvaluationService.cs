// ================================================================================
// BACKUP — Pre-centralization snapshot of IPromotionEvaluationService.
// Kept as read-only reference. Do NOT edit. Do NOT register for DI.
// See d:\KLS\AI-Development\plan\promo-centralization.md.
// ================================================================================

using KLS.Models.PromotionEval;

namespace KLS.Contract.Services
{
    public interface _IPromotionEvaluationService
    {
        PromotionEvalResponse EvaluateCart(PromotionEvalRequest request);
        PromotionEvalResponse TogglePromotion(PromoToggleRequest request);
    }
}
