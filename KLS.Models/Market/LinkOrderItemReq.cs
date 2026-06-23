namespace KLS.Models
{
    public class LinkOrderItemReq
    {
        public int MarketOrderItemId { get; set; }
        public int ItemId { get; set; }
        public int ItemUnitId { get; set; }
        public string? BarcodeAction { get; set; }
        public string? NewBarcode { get; set; }
    }
}
