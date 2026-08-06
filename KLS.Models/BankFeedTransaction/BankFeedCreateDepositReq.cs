namespace KLS.Models
{
    /// <summary>
    /// Create a Deposit from a pending money-in bank feed row (Phase 2a).
    /// Deliberately absent: DepositDate (always the bank row's PostedDate) and any
    /// per-payment amount (a deposit takes each payment's full PaymentAmount).
    /// </summary>
    public class BankFeedCreateDepositReq
    {
        public long BankFeedTransactionId { get; set; }

        public List<int> CustomerPaymentIds { get; set; } = new();

        /// <summary>'None' | 'BankFee' | 'Rounding' | 'Account'</summary>
        public string DifferenceKind { get; set; } = "None";

        /// <summary>Required when DifferenceKind = 'Account'.</summary>
        public int? DifferenceAccountId { get; set; }

        /// <summary>Required when DifferenceKind is not 'None'.</summary>
        public string? DifferenceMemo { get; set; }
    }
}
