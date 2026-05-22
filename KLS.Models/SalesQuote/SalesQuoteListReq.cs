namespace KLS.Models
{
    public class SalesQuoteListReq : PagingRequest
    {
        public int? PayeeId { get; set; }
    }
}
