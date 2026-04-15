using System.Collections.Generic;

namespace KLS.Models
{
    // Inventory item upsert payload (PUT /sell/inventory/v1/inventory_item/{sku})
    public class EbayInventoryItemRequest
    {
        public EbayInventoryProduct? product { get; set; }
        public EbayInventoryAvailability? availability { get; set; }
        public string? condition { get; set; }
    }

    public class EbayInventoryProduct
    {
        public string? title { get; set; }
        public string? description { get; set; }
        public List<string>? imageUrls { get; set; }
        public Dictionary<string, List<string>>? aspects { get; set; }
    }

    public class EbayInventoryAvailability
    {
        public EbayShipToLocationAvailability? shipToLocationAvailability { get; set; }
    }

    public class EbayShipToLocationAvailability
    {
        public int quantity { get; set; }
    }

    // Offer create/update payload (POST /sell/inventory/v1/offer, PUT /sell/inventory/v1/offer/{offerId})
    public class EbayOfferRequest
    {
        public string? sku { get; set; }
        public string? marketplaceId { get; set; }
        public string? format { get; set; }
        public int availableQuantity { get; set; }
        public string? categoryId { get; set; }
        public string? merchantLocationKey { get; set; }
        public EbayPricingSummary? pricingSummary { get; set; }
        public EbayListingPolicies? listingPolicies { get; set; }
    }

    public class EbayPricingSummary
    {
        public EbayAmount? price { get; set; }
    }

    public class EbayAmount
    {
        public string? value { get; set; }
        public string? currency { get; set; }
    }

    public class EbayListingPolicies
    {
        public string? fulfillmentPolicyId { get; set; }
        public string? paymentPolicyId { get; set; }
        public string? returnPolicyId { get; set; }
    }

    // Offer response (POST offer)
    public class EbayOfferResponse
    {
        public string? offerId { get; set; }
        public string? sku { get; set; }
        public string? marketplaceId { get; set; }
        public string? status { get; set; } // PUBLISHED, UNPUBLISHED, ENDED
        public string? listingId { get; set; }
        public List<EbayListingIssue>? listing { get; set; }
    }

    // Publish response
    public class EbayPublishResponse
    {
        public string? listingId { get; set; }
        public List<string>? warnings { get; set; }
    }

    // Withdraw response (POST /offer/{id}/withdraw)
    public class EbayWithdrawResponse
    {
        public string? listingId { get; set; }
    }

    public class EbayListingIssue
    {
        public string? errorId { get; set; }
        public string? message { get; set; }
        public string? severity { get; set; }
        public string? category { get; set; }
    }

    // Get offer response (for RefreshStatusAsync)
    public class EbayGetOfferResponse
    {
        public string? offerId { get; set; }
        public string? sku { get; set; }
        public string? status { get; set; }
        public string? listingId { get; set; }
        public string? format { get; set; }
        public string? marketplaceId { get; set; }
        public EbayListingDetails? listing { get; set; }
    }

    public class EbayListingDetails
    {
        public string? listingId { get; set; }
        public string? listingStatus { get; set; }
    }
}
