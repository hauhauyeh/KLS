using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace KLS.Models.Reports
{
    public class RptWorksheet
    {
        [Key]
        public long Id { get; set; }

        public string? ItemCode { get; set; }

        public string? ItemDesc1 { get; set; }

        public string? ItemDescX1 { get; set; }

        public string? Category0 { get; set; }

        public string? Unit { get; set; }

        [Column(TypeName = "decimal(18,6)")]
        public decimal? CloQty { get; set; }

        [Column(TypeName = "decimal(18,6)")]
        public decimal? FutureChg { get; set; }

        public string? Storage { get; set; }

        public string? PackSize { get; set; }

        [Column(TypeName = "decimal(18,6)")]
        public decimal? MostOrdered { get; set; }

        public string? PayeeName { get; set; }

        [Column(TypeName = "decimal(18,6)")]
        public decimal? M1 { get; set; }

        [Column(TypeName = "decimal(18,6)")]
        public decimal? M2 { get; set; }

        [Column(TypeName = "decimal(18,6)")]
        public decimal? M3 { get; set; }

        [Column(TypeName = "decimal(18,6)")]
        public decimal? M4 { get; set; }

        [Column(TypeName = "decimal(18,6)")]
        public decimal? M5 { get; set; }

        [Column(TypeName = "decimal(18,6)")]
        public decimal? M6 { get; set; }
    }

    public class RptWorksheetGroup
    {
        public string? Group { get; set; }

        public List<RptWorksheet> Items { get; set; } = new();
    }
}
