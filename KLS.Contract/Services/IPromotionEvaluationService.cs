using KLS.Models.PromotionEval;

namespace KLS.Contract.Services
{
    public interface IPromotionEvaluationService
    {
        PromotionEvalResponse EvaluateCart(PromotionEvalRequest request);
        PromotionEvalResponse TogglePromotion(PromoToggleRequest request);
    }
}
