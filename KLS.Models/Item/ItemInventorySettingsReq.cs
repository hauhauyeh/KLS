namespace KLS.Models
{
    public class ItemInventorySettingsReq
    {
        public int ItemId { get; set; }
        public decimal? ActualSaftyInventory { get; set; }
        public decimal? RefillInventory { get; set; }
        public decimal? CaseLength { get; set; }
        public decimal? CaseWidth { get; set; }
        public decimal? CaseHeight { get; set; }
        public decimal? CaseVolumeInCubicMeter { get; set; }
        public decimal? CaseWeight { get; set; }
        public bool? IsVolumeManual { get; set; }
    }
}
