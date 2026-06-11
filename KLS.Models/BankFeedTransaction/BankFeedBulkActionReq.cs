namespace KLS.Models
{
    public class BankFeedBulkActionReq
    {
        public List<long> BankFeedTransactionIds { get; set; } = new();
    }
}
