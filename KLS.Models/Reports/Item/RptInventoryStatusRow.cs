using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace KLS.Models.Reports
{
    public class RptInventoryStatusRow
    {
        [Key]
        public Int64 AutoId { get; set; }

        public int ItemId { get; set; }

        public string? ItemCode { get; set; }

        public string? ItemName { get; set; }

        public string? Cat0 { get; set; }

        public string? Cat1 { get; set; }

        public int? Sort0 { get; set; }

        public int? Sort1 { get; set; }

        public string? StorageName { get; set; }

        public string? Unit { get; set; }

        [Column(TypeName = "decimal(18,6)")]
        public decimal? OnHand { get; set; }

        [Column(TypeName = "decimal(18,6)")]
        public decimal? FutureSales { get; set; }

        [Column(TypeName = "decimal(18,6)")]
        public decimal? TotalIncoming { get; set; }

        [Column(TypeName = "decimal(18,6)")]
        public decimal? LAvgCost { get; set; }

        [Column(TypeName = "decimal(18,6)")]
        public decimal? LInventoryValue { get; set; }

        public decimal? RefillInventory { get; set; }

        public decimal? ActualSaftyInventory { get; set; }

        public decimal? M0 { get; set; }

        public decimal? M1 { get; set; }

        public decimal? M2 { get; set; }

        public decimal? M3 { get; set; }

        public decimal? YTD { get; set; }

        public decimal? Last3M { get; set; }

        public DateTime? ExpiryDate { get; set; }

        public bool Inactive { get; set; }

        public int? PreferredVendorId { get; set; }

        public string? VendorName { get; set; }
    }
}
