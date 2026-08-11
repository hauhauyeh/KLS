namespace KLS.Models
{
    /// <summary>
    /// Filter for the open-bill lookup behind the Bank Feed "Create Vendor Payment" modal.
    /// PayeeId is optional: null (or 0) lists open bills across all vendors, so one bank
    /// debit can pay bills of several vendors. A value still narrows to that vendor.
    /// </summary>
    public class BankFeedOpenBillsReq : PagingRequest
    {
        public long BankFeedTransactionId { get; set; }

        public int? PayeeId { get; set; }
    }
}
