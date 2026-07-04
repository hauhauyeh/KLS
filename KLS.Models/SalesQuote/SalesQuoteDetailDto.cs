namespace KLS.Models
{
    public class SalesQuoteDetailDto
    {
        public SalesQuote? SalesQuote { get; set; }
        public ICollection<SalesQuoteDetailList>? Details { get; set; }
        public string? PayeeName { get; set; }
    }
}
