namespace KLS.Models
{
    public class CRMLeadListReq : PagingRequest
    {
        public string? Stage { get; set; }

        public int? SalesRepId { get; set; }
    }
}
