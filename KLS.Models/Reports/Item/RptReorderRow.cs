using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace KLS.Models.Reports
{
    public class RptReorderRow
    {
        [Key]
        public Int64 AutoId { get; set; }

        public int ItemId { get; set; }

        public string? ItemCode { get; set; }

        public string? ItemName { get; set; }

        public string? Cat0 { get; set; }

        public int? Sort0 { get; set; }

        public string? Unit { get; set; }

        public string? StorageName { get; set; }

        [Column(TypeName = "decimal(18,6)")]
        public decimal? OnHand { get; set; }

        public decimal? RefillInventory { get; set; }

        public decimal? ActualSaftyInventory { get; set; }

        public decimal? Last3M { get; set; }

        [Column(TypeName = "decimal(38,16)")]
        public decimal? DaysOfSupply { get; set; }

        [Column(TypeName = "decimal(18,6)")]
        public decimal? SuggestedQty { get; set; }

        [Column(TypeName = "decimal(18,6)")]
        public decimal? LAvgCost { get; set; }

        [Column(TypeName = "decimal(38,12)")]
        public decimal? ReorderValue { get; set; }

        [Column(TypeName = "decimal(18,6)")]
        public decimal? TotalIncoming { get; set; }

        public string? VendorName { get; set; }

        public int? PreferredVendorId { get; set; }
    }
}
