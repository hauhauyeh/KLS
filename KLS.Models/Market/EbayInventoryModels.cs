namespace KLS.Models
{
    // Partial-update payload for PUT /sell/inventory/v1/inventory_item/{sku} (quantity-only)
    public class EbayInventoryQuantityUpdateRequest
    {
        public EbayInventoryAvailability? availability { get; set; }
    }
}
