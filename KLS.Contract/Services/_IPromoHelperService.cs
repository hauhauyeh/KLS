// ================================================================================
// BACKUP — Pre-centralization snapshot of IPromoHelperService.
// Kept as read-only reference. Do NOT edit. Do NOT register for DI.
// See d:\KLS\AI-Development\plan\promo-centralization.md.
// ================================================================================

using KLS.Models;

namespace KLS.Contract.Services
{
    public interface _IPromoHelperService
    {
        List<PromotionSummary> GetAvailablePromotions(int salesId, int payeeId);
        PromotionResult ApplyPromotion(int salesId, int payeeId);
    }
}
