namespace KLS.Models
{
    /// <summary>
    /// Filter for the open-invoice lookup behind the Bank Feed "Receive New Payment" tab.
    /// PayeeId is required: 2b creates one payment per payer. The SP resolves the bill-to
    /// parent, so a payer's invoices may span several ship-to payees.
    /// </summary>
    public class BankFeedOpenInvoicesReq : PagingRequest
    {
        public long BankFeedTransactionId { get; set; }

        public int PayeeId { get; set; }
    }
}
