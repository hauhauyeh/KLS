namespace KLS.Models
{
    /// <summary>
    /// One active item-level promo attached to an Item. Returned by
    /// PromoHelperService.GetActiveItemDiscounts() as Dictionary&lt;ItemId, ItemPromoDiscount&gt;.
    /// Used by web browse + home decoration to render "-X%" badges and strike-through prices.
    /// Catalog-level: no customer context applied (shown uniformly to all visitors).
    /// </summary>
    public class ItemPromoDiscount
    {
        public int PromotionId { get; set; }
        public string? Name { get; set; }
        public string? DisplayName { get; set; }

        /// <summary>DISCOUNT_ITEM_FLAT or DISCOUNT_ITEM_PERCENTAGE.</summary>
        public string? PromotionType { get; set; }

        /// <summary>Flat $ for DISCOUNT_ITEM_FLAT; percent (0-100) for DISCOUNT_ITEM_PERCENTAGE.</summary>
        public decimal? DiscountValue { get; set; }

        public decimal? MaxDiscountAmount { get; set; }
    }
}
