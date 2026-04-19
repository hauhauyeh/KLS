using KLS.Models;
using KLS.Models.PromotionEval;

namespace KLS.Contract.Services
{
    /// <summary>
    /// Unified promo service. Mutating methods (ApplyPromotion) persist discounts and
    /// free rows to TempSales; read-only methods (EvaluateCart, GetActiveItemDiscounts,
    /// GetAvailablePromotions) never touch the database. See
    /// d:\KLS\AI-Development\plan\promo-centralization.md for the full contract.
    /// </summary>
    public interface IPromoHelperService
    {
        // --- Read-only ---

        /// <summary>
        /// Preview promo outcome for a cart without mutating TempSales. Request overload
        /// provided for admin DI compatibility (same signature as the retired
        /// IPromotionEvaluationService.EvaluateCart).
        /// </summary>
        PromoEvaluationResult EvaluateCart(PromotionEvalRequest request);

        /// <summary>Preview promo outcome by salesId/payeeId. Same semantics as the request overload.</summary>
        PromoEvaluationResult EvaluateCart(int salesId, int payeeId);

        /// <summary>
        /// All items currently under an item-level promo (DISCOUNT_ITEM_FLAT /
        /// DISCOUNT_ITEM_PERCENTAGE) keyed by ItemId. Catalog-level — no customer
        /// eligibility applied; intended for browse badges visible to every visitor.
        /// </summary>
        Dictionary<int, ItemPromoDiscount> GetActiveItemDiscounts();

        /// <summary>
        /// Catalog-visible item offer badges keyed by ItemId. Intended for promos
        /// that should be advertised as an offer message instead of a direct price
        /// markdown, such as BOGO item/category rules.
        /// </summary>
        Dictionary<int, string> GetActiveItemOfferBadges();

        /// <summary>Qualifying promos summary for a cart. Used by admin list-of-qualifying-promos UI.</summary>
        List<PromotionSummary> GetAvailablePromotions(int salesId, int payeeId);

        // --- Mutating (persists to TempSales) ---

        /// <summary>
        /// Evaluate and APPLY promos to the cart — writes discounts to paid rows,
        /// inserts BOGO reward rows, returns the applied totals. Called on checkout.
        /// </summary>
        PromotionResult ApplyPromotion(int salesId, int payeeId);

        /// <summary>
        /// Per-user opt-in/out for BOGO promos. Toggling on reprices the owner line
        /// to PromoPrice and injects a linked reward line; toggling off restores the
        /// owner and removes the reward. Migrated from IPromotionEvaluationService.
        /// </summary>
        PromoEvaluationResult TogglePromotion(PromoToggleRequest request);
    }
}
