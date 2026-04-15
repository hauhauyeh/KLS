namespace KLS.Models
{
    // Partial-update payload for PUT /sell/inventory/v1/offer/{offerId}
    public class EbayOfferPriceUpdateRequest
    {
        public EbayPricingSummary? pricingSummary { get; set; }
    }
}
