using System.ComponentModel.DataAnnotations;

namespace KLS.Models.Reports
{
    public class RptBasicItemRow
    {
        [Key]
        public int ItemId { get; set; }

        public string? Category { get; set; }
        public int? CategorySort0 { get; set; }
        public int? CategorySort1 { get; set; }
        public int? CategorySort2 { get; set; }
        public int? CategorySort3 { get; set; }
        public int? CategorySort4 { get; set; }
        public int? CategorySort5 { get; set; }

        public string? ItemCode { get; set; }
        public string? ItemName { get; set; }
        public string? UnitPackSize { get; set; }
        public string? Dimension { get; set; }
        public string? Weight { get; set; }
    }
}
