namespace KLS.Models
{
    public class WebPublicSettingsDto
    {
        public string PortalMode { get; set; } = "B2B";

        public bool EnforceStockLimit { get; set; }

        public string CurrencyCode { get; set; } = "USD";

        public string? MetaTitle { get; set; }

        public string? MetaTitleShort { get; set; }

        public string? MetaDesc { get; set; }

        public string? Keywords { get; set; }

        public string? GoogleTagId { get; set; }

        public string? JsonLd { get; set; }

        public int OrderCheckoutHour { get; set; }
    }
}
