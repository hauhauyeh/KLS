namespace KLS.Models
{
    public class CountryDto
    {
        public int CountryId { get; set; }

        public string CountryName { get; set; } = string.Empty;

        public string ISOAlpha2 { get; set; } = string.Empty;

        public string ISOAlpha3 { get; set; } = string.Empty;

        public string? NumericCode { get; set; }

        public string? CallingCode { get; set; }

        public string? Continent { get; set; }

        public bool IsActive { get; set; }

        public int? SortOrder { get; set; }
    }
}
