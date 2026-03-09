using KLS.Models;

namespace KLS.Contract.Services
{
    public interface IPromoHelperService
    {
        List<PromotionSummary> GetAvailablePromotions(int salesId, int payeeId);
        PromotionResult ApplyPromotion(int salesId, int payeeId);
    }
}
