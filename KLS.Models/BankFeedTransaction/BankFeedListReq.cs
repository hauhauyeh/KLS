namespace KLS.Models
{
    public class BankFeedListReq : PagingRequest
    {
        public int? AccountId { get; set; }

        public string? Status { get; set; }

        public string? AmountDirection { get; set; }
    }
}
