using System;
using System.ComponentModel.DataAnnotations;

namespace KLS.Models.Reports
{
    // Row for the Item Analysis report (Report_ItemAnalysis): one per item, with journal-sourced
    // qty/amount/cost/margin plus the dimensions used for grouping (Cat0/Cat1, StorageName) and
    // sorting (Last3M, ExpiryDate). All nullable except the [Key] -- the SP ISNULLs the aggregates
    // but Last3M/ExpiryDate/category/storage can legitimately be null.
    public class RptItemAnalysis
    {
        [Key]
        public int ItemId { get; set; }

        public string? ItemCode { get; set; }
        public string? ItemName { get; set; }
        public string? Cat0 { get; set; }
        public string? Cat1 { get; set; }
        public string? StorageName { get; set; }
        public decimal? Last3M { get; set; }
        public DateOnly? ExpiryDate { get; set; }
        public decimal? Qty { get; set; }
        public decimal? Amount { get; set; }
        public decimal? SalesPerc { get; set; }
        public decimal? Cost { get; set; }
        public decimal? GrossMargin { get; set; }
        public decimal? GrossMarginPerc { get; set; }
    }
}
