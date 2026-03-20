namespace KLS.Models
{
    public class ItemInventorySettingsReq
    {
        public int ItemId { get; set; }
        public decimal? ActualSaftyInventory { get; set; }
        public decimal? RefillInventory { get; set; }
    }
}
