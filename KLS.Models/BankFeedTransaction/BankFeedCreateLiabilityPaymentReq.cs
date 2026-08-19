namespace KLS.Models
{
    /// <summary>
    /// Create a tax or loan liability payment from a pending money-out bank feed row.
    /// The kind (tax vs loan) is derived server-side from the payee's PayeeType; the split
    /// fields apply to loan payees only and must sum to ABS(bank amount). The payment amount
    /// and date are never sent - the SP takes them from the bank row.
    /// Plan: plan/bank-feed-liability-payment-v1.md
    /// </summary>
    public class BankFeedCreateLiabilityPaymentReq
    {
        public long BankFeedTransactionId { get; set; }

        public int PayeeId { get; set; }

        public string? PaymentMethod { get; set; }

        public string? ReferenceId { get; set; }

        public string? Notes { get; set; }

        public decimal Principal { get; set; }

        public decimal Interest { get; set; }

        public decimal LateFee { get; set; }

        /// <summary>Append the bank row's description to the payment notes (default on).</summary>
        public bool AppendBankDescription { get; set; } = true;
    }
}
