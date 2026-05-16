namespace KLS.Models
{
    public class BankFeedExcludeReq
    {
        public long BankFeedTransactionId { get; set; }

        public string? ExcludeReason { get; set; }
    }
}
