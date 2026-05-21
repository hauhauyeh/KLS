using System.ComponentModel.DataAnnotations;

namespace KLS.Models.Reports
{
    public class RptItemVendorAnalysisRow
    {
        [Key]
        public int PayeeId { get; set; }

        public string? PayeeName { get; set; }

        public decimal QtyPurchased { get; set; }

        public decimal TotalCost { get; set; }

        public decimal AvgUnitCost { get; set; }

        public decimal? PercentOfSpend { get; set; }

        public DateOnly? LastPurchase { get; set; }

        public int? DaysSinceLast { get; set; }
    }
}
