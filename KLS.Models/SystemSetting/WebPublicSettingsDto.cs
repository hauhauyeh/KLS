namespace KLS.Models
{
    public class WebPublicSettingsDto
    {
        public string PortalMode { get; set; } = "B2B";

        public bool EnforceStockLimit { get; set; }

        public string CurrencyCode { get; set; } = "USD";
    }
}
