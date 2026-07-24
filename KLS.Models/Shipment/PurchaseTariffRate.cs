namespace KLS.Models
{
    public class PurchaseTariffRatePrecheckRow
    {
        public int PurchaseDetailId { get; set; }
        public int PurchaseId { get; set; }
        public int? LineId { get; set; }
        public int? ItemId { get; set; }
        public string ItemCode { get; set; } = "";
        public string ItemName { get; set; } = "";
        public string? CountryCode { get; set; }
        public string? HSNCode { get; set; }
        public decimal? LineDutyRate { get; set; }
        public decimal? LineTariffRate { get; set; }
        public decimal? CurrentDutyRate { get; set; }
        public decimal? CurrentTariffRate { get; set; }
        public string Status { get; set; } = "";
    }

    public class PurchaseTariffRatePrecheckResult
    {
        public int MatchCount { get; set; }
        public int DifferentCount { get; set; }
        public int MissingSetupCount { get; set; }
        public int NoCountryCount { get; set; }
        public List<PurchaseTariffRatePrecheckRow> Rows { get; set; } = new();
    }

    public class PurchaseTariffRateRefreshResult
    {
        public int UpdatedCount { get; set; }
        public int SkippedMissingSetupCount { get; set; }
    }
}
