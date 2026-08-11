namespace KLS.Models
{
    public class SalesQuoteSaveReq
    {
        public int PayeeId { get; set; }
        public DateOnly? ExpiryDate { get; set; }
        public string? Notes { get; set; }
        public int StatusId { get; set; }
        public string? SalesQuoteType { get; set; }
    }
}
