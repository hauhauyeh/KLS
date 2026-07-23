namespace KLS.Models
{
    public class SalesQuoteEmailContextDto
    {
        public int SalesQuoteId { get; set; }

        public int QuoteNumber { get; set; }

        public int PayeeId { get; set; }

        public string? PayeeName { get; set; }

        public string? Email { get; set; }

        public string? EmailPricesheet { get; set; }

        public string? DefaultEmail { get; set; }

        public bool CanSaveToEmailPricesheet { get; set; }
    }
}
