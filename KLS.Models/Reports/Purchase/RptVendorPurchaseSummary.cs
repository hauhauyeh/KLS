using System;
using System.ComponentModel.DataAnnotations;

namespace KLS.Models.Reports
{
    public class RptVendorPurchaseSummary
    {
        [Key]
        public int VendorId { get; set; }

        public string? VendorName { get; set; }

        public decimal? Last3M { get; set; }

        public decimal? M0 { get; set; }

        public decimal? M1 { get; set; }

        public decimal? M2 { get; set; }

        public decimal? M3 { get; set; }

        public decimal? YTD { get; set; }

        public decimal? LYTD { get; set; }

        public int? TotalBills { get; set; }

        public DateOnly? LastPurchase { get; set; }
    }
}
