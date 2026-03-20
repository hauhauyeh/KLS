using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace KLS.Models.Reports
{
    public class RptInventoryMovementRow
    {
        [Key]
        public Int64 AutoId { get; set; }

        public int ItemId { get; set; }

        public string? ItemCode { get; set; }

        public string? ItemName { get; set; }

        public string? Cat0 { get; set; }

        public int? Sort0 { get; set; }

        public string? StorageName { get; set; }

        public string? Unit { get; set; }

        [Column(TypeName = "decimal(18,6)")]
        public decimal? OnHand { get; set; }

        public decimal? M0 { get; set; }

        public decimal? M1 { get; set; }

        public decimal? M2 { get; set; }

        public decimal? M3 { get; set; }

        public decimal? Last3M { get; set; }

        public decimal? YTD { get; set; }

        [Column(TypeName = "decimal(18,4)")]
        public decimal? YTDSalesPercent { get; set; }

        public DateTime? ExpiryDate { get; set; }

        public int? DaysSinceLastSold { get; set; }

        public int? PreferredVendorId { get; set; }

        public string? VendorName { get; set; }
    }
}
