namespace KLS.Models
{
    /// <summary>Reverse a transaction Bank Feed created from a bank row.</summary>
    public class BankFeedReverseReq
    {
        public long BankFeedTransactionId { get; set; }

        public string? ReverseReason { get; set; }
    }
}
