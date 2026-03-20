using System.ComponentModel.DataAnnotations;

namespace KLS.Models.Reports
{
    public class RptCustItemVolume
    {
        [Key]
        public string? ItemCode { get; set; }

        public string? ItemName { get; set; }

        public string? Unit { get; set; }

        public string? Cat0 { get; set; }

        public string? Cat1 { get; set; }

        public decimal? M1 { get; set; }

        public decimal? M2 { get; set; }

        public decimal? M3 { get; set; }

        public decimal? M4 { get; set; }

        public decimal? M5 { get; set; }

        public decimal? M6 { get; set; }
    }
}
