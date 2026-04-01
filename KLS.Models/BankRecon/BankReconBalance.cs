namespace KLS.Models
{
    public class BankReconBalance
    {
        public decimal? BeginningBalance { get; set; }

        public decimal? DepositAmt { get; set; }

        public decimal? CheckAmt { get; set; }

        public decimal? StatementBalance { get; set; }

        public decimal? EndingBalance { get; set; }

        public decimal? DifferenceAmount { get; set; }

        public DateOnly? BeginningDate { get; set; }

        public DateOnly? StatementDate { get; set; }

        public bool IsReconciled { get; set; }

        public decimal? SystemBalance { get; set; }
    }
}
