using System.ComponentModel.DataAnnotations;

namespace KLS.Models.Reports
{
    public class RptBankReconRow
    {
        [Key]
        public int RowId { get; set; }

        public int? TxId { get; set; }

        public DateOnly? TxDate { get; set; }

        public string? SourceDocType { get; set; }

        public int? SourceDocNumber { get; set; }

        public string? PayeeName { get; set; }

        public decimal? Amount { get; set; }

        public DateOnly? BankDate { get; set; }

        public int IsCleared { get; set; }

        public string? AccountName { get; set; }

        public DateOnly? StatementDate { get; set; }

        public decimal? StatementBalance { get; set; }

        public decimal? BeginningBalance { get; set; }
    }

    public class RptBankRecon
    {
        public string? AccountName { get; set; }

        public DateOnly? StatementDate { get; set; }

        public decimal? StatementBalance { get; set; }

        public decimal? BeginningBalance { get; set; }

        public List<RptBankReconRow>? ClearedDeposits { get; set; }

        public List<RptBankReconRow>? ClearedPayments { get; set; }

        public List<RptBankReconRow>? OutstandingDeposits { get; set; }

        public List<RptBankReconRow>? OutstandingPayments { get; set; }

        public decimal? TotalClearedDeposits { get; set; }

        public decimal? TotalClearedPayments { get; set; }

        public decimal? TotalOutstandingDeposits { get; set; }

        public decimal? TotalOutstandingPayments { get; set; }
    }
}
