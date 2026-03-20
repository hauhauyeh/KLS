using System.ComponentModel.DataAnnotations;

namespace KLS.Models.Reports
{
    // Flat row from Report_ARMonth SP
    public class RptARMonthRow
    {
        [Key]
        public int PayeeId { get; set; }

        public string? Region { get; set; }

        public string? PayeeName { get; set; }

        public string? PhoneDesc1 { get; set; }

        public string? Phone1 { get; set; }

        public decimal? Total { get; set; }
    }

    // Grouped response for API
    public class RptARMonth
    {
        public List<RptARMonthRegion>? Regions { get; set; }

        public decimal? Total { get; set; }
    }

    public class RptARMonthRegion
    {
        public string? Region { get; set; }

        public decimal? Total { get; set; }

        public List<RptARMonthRow>? Customers { get; set; }
    }
}
