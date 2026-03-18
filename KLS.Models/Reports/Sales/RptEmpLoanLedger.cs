using System.ComponentModel.DataAnnotations;

namespace KLS.Models.Reports
{
    public class RptEmpLoanLedger
    {
        [Key]
        public int AutoId { get; set; }

        public int? PayeeId { get; set; }

        public string? PayeeName { get; set; }

        public int? TxNum { get; set; }

        public DateOnly? TxDate { get; set; }

        public string? SourceDocType { get; set; }

        public int? SourceDocNum { get; set; }

        public decimal? Amount { get; set; }

        public decimal? DebitAmt { get; set; }

        public decimal? CreditAmt { get; set; }

        public decimal? AcctBalance { get; set; }

        public decimal? OpeningBalance { get; set; }
    }
}
