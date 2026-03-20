using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace KLS.Models.Reports
{
    public class RptInventoryValuationRow
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

        public string? Unit { get; set; }

        [Column(TypeName = "decimal(18,6)")]
        public decimal? OnHand { get; set; }

        [Column(TypeName = "decimal(18,6)")]
        public decimal? LAvgCost { get; set; }

        [Column(TypeName = "decimal(38,12)")]
        public decimal? Value { get; set; }

        public int? PreferredVendorId { get; set; }

        public string? VendorName { get; set; }
    }
}
