using KLS.Common;
using KLS.Models;

namespace KLS.API.Decorators
{
    /// <summary>
    /// Applies active item-level promo discounts (DISCOUNT_ITEM_FLAT /
    /// DISCOUNT_ITEM_PERCENTAGE) to each <see cref="ItemWebUnitList"/> inside a
    /// collection of <see cref="ItemWebList"/>. Called by web item / catalog
    /// controllers after fetching the paged item list. Per-unit
    /// MaxDiscountAmount clamp lives here — not in the centralized promo service,
    /// which only returns metadata without per-unit price knowledge.
    /// </summary>
    public static class ItemWebListPromoDecorator
    {
        public static void ApplyPromoDecoration(
            this IEnumerable<ItemWebList>? items,
            Dictionary<int, ItemPromoDiscount>? discountMap,
            Dictionary<int, string>? offerBadgeMap = null)
        {
            if (items == null) return;

            foreach (var item in items)
            {
                if (offerBadgeMap != null && offerBadgeMap.TryGetValue(item.ItemId, out var badgeText))
                {
                    item.PromoBadgeText = badgeText;
                }

                if (discountMap == null || !discountMap.TryGetValue(item.ItemId, out var promo)) continue;
                if (item.ItemUnits == null || promo.DiscountValue is not > 0m) continue;

                foreach (var unit in item.ItemUnits)
                {
                    var originalPrice = unit.Price ?? 0m;
                    if (originalPrice <= 0m) continue;

                    // Compute per-unit discount amount.
                    var rawDiscount = promo.PromotionType == nameof(EnumHelper.PromotionType.DISCOUNT_ITEM_FLAT)
                        ? promo.DiscountValue!.Value
                        : originalPrice * (promo.DiscountValue!.Value / 100m);

                    // Per-unit clamp. MaxDiscountAmount on item-level promos caps
                    // each unit's reduction (not a cart-wide cap — admin should use
                    // a cart-level promo for that).
                    if (promo.MaxDiscountAmount.HasValue)
                        rawDiscount = Math.Min(rawDiscount, promo.MaxDiscountAmount.Value);

                    var newPrice = Math.Max(0m, originalPrice - rawDiscount);

                    unit.MarketPrice = originalPrice;                                  // preserve original for strike-through
                    unit.Price = Utilities.Rounding(newPrice, 2);                      // discounted price, rounded to cents
                    unit.Discount = Math.Round(((originalPrice - newPrice) / originalPrice) * 100m, 0);
                }
            }
        }
    }
}
