using System.ComponentModel.DataAnnotations;

namespace KLS.Models.Reports
{
    public class RptCustSalesByItem
    {
        [Key]
        public long AutoId { get; set; }

        public int? PayeeId { get; set; }

        public string? PayeeName { get; set; }

        public string? ItemCode { get; set; }

        public string? ItemName { get; set; }

        public string? Cat0 { get; set; }

        public string? Cat1 { get; set; }

        public decimal? Qty { get; set; }

        public decimal? Amount { get; set; }

        public decimal? SalesPerc { get; set; }

        public decimal? AvgPrice { get; set; }

        public decimal? Cost { get; set; }

        public decimal? AvgCost { get; set; }

        public decimal? GrossMargin { get; set; }

        public decimal? GrossMarginPerc { get; set; }
    }
}
