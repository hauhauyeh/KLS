namespace KLS.Models
{
    /// <summary>
    /// Filter for the undeposited-payment lookup behind the Bank Feed "Create Deposit" modal.
    /// No PayeeId, unlike BankFeedOpenBillsReq: a deposit is a batch across customers, so
    /// Search is a convenience rather than a gate.
    /// </summary>
    public class BankFeedUndepositedPaymentsReq : PagingRequest
    {
        public long BankFeedTransactionId { get; set; }

        /// <summary>Exact-match payment method filter; null/empty = all methods.</summary>
        public string? PaymentMethod { get; set; }
    }
}
