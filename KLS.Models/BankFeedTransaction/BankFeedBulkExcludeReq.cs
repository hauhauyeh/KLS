namespace KLS.Models
{
    public class BankFeedBulkExcludeReq
    {
        public List<long> BankFeedTransactionIds { get; set; } = new();

        public string? ExcludeReason { get; set; }
    }
}
