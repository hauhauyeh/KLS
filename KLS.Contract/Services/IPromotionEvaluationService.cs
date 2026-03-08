using KLS.Models;

namespace KLS.Contract.Services
{
    public interface IPromotionEvaluationService
    {
        PromotionEvalResponse EvaluateCart(PromotionEvalRequest request);
    }
}
