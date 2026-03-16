using System.ComponentModel.DataAnnotations;

namespace KLS.Models.Reports
{
    public class RptLedgerRow
    {
        [Key]
        public long TxNum { get; set; }

        public DateOnly TxDate { get; set; }

        public string? Payee { get; set; }

        public string? DocType { get; set; }

        public decimal Debit { get; set; }

        public decimal Credit { get; set; }

        public decimal Amount { get; set; }

        public decimal OpeningBalance { get; set; }
    }
}
