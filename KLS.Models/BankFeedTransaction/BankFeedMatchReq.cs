namespace KLS.Models
{
    public class BankFeedMatchReq
    {
        public long BankFeedTransactionId { get; set; }

        public long? TxId { get; set; }

        public long? TxDetailId { get; set; }
    }
}
