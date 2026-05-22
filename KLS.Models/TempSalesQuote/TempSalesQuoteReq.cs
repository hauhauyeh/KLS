namespace KLS.Models
{
    public class TempSalesQuoteReq
    {
        public int PayeeId { get; set; }
        public int SalesQuoteId { get; set; }
        public string? SortField { get; set; }
        public string? SortOrder { get; set; }
        public int? TempId { get; set; }
        public string? SearchTerm { get; set; }
    }
}
