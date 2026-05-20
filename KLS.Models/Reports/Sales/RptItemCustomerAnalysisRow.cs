using System.ComponentModel.DataAnnotations;

namespace KLS.Models.Reports
{
    public class RptItemCustomerAnalysisRow
    {
        [Key]
        public int PayeeId { get; set; }

        public string? PayeeName { get; set; }

        public decimal QtySold { get; set; }

        public decimal SalesAmount { get; set; }

        public decimal AvgPrice { get; set; }

        public decimal TotalCost { get; set; }

        public decimal? MarginPercent { get; set; }

        public DateOnly? LastPurchase { get; set; }

        public int? DaysSinceLast { get; set; }
    }
}
