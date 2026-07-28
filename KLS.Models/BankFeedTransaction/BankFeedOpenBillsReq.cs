namespace KLS.Models
{
    /// <summary>
    /// Filter for the open-bill lookup behind the Bank Feed "Create Vendor Payment" modal.
    /// PayeeId is required: a vendor payment carries a single PayeeId, so the vendor is a
    /// filter for the list rather than a per-row choice.
    /// </summary>
    public class BankFeedOpenBillsReq : PagingRequest
    {
        public long BankFeedTransactionId { get; set; }

        public int PayeeId { get; set; }
    }
}
