using System.ComponentModel.DataAnnotations;

namespace KLS.Models.Reports
{
    public class RptLedgerByPayeeRow
    {
        [Key]
        public int AutoId { get; set; }

        public DateOnly? TxDate { get; set; }

        public int? TxNum { get; set; }

        public string? SourceDocType { get; set; }

        public int? SourceDocNum { get; set; }

        public string? PayeeName { get; set; }

        public decimal? Amount { get; set; }

        public string? ChartAcctName { get; set; }

        public decimal? AcctBalance { get; set; }

        public decimal? OpeningBalance { get; set; }
    }
}
