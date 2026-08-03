namespace KLS.Models
{
    public class WebPublicSettingsDto
    {
        public string? ClientKey { get; set; }

        public string? CompanyCode { get; set; }

        public string? CompanyDisplayName { get; set; }

        public CompanyIdentityDto? CompanyIdentity { get; set; }

        public CompanyContactDto? CompanyContact { get; set; }

        public string PortalMode { get; set; } = "B2B";

        public bool EnforceStockLimit { get; set; }

        public bool UseSalesDocNumber { get; set; }

        public bool PublicProductListEnabled { get; set; }

        public string CurrencyCode { get; set; } = "USD";

        public string? MetaTitle { get; set; }

        public string? MetaTitleShort { get; set; }

        public string? MetaDesc { get; set; }

        public string? Keywords { get; set; }

        public string? GoogleTagId { get; set; }

        public string? JsonLd { get; set; }

        public int OrderCheckoutHour { get; set; }

        public object? ClientExperience { get; set; }
    }

    public class CompanyIdentityDto
    {
        public string? Code { get; set; }

        public string? DisplayName { get; set; }

        public string? CompanyName { get; set; }

        public string? Website { get; set; }

        public string? WebLogoUrl { get; set; }

        public string? WebFaviconUrl { get; set; }
    }

    public class CompanyContactDto
    {
        public string? Phone { get; set; }

        public string? SupportPhone { get; set; }

        public string? Email { get; set; }

        public string? SupportEmail { get; set; }

        public string? SalesEmail { get; set; }

        public string? PublicContactName { get; set; }

        public string? PublicAddressName { get; set; }

        public string? AddressLine1 { get; set; }

        public string? AddressLine2 { get; set; }

        public string? City { get; set; }

        public string? State { get; set; }

        public string? ZipCode { get; set; }

        public string? CountryCode { get; set; }

        public string? FullAddress { get; set; }

        public string? BusinessHours { get; set; }
    }
}
