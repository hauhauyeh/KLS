using System.ComponentModel.DataAnnotations;

namespace KLS.Models
{
    public class SalesQuoteList
    {
        [Key]
        public int SalesQuoteId { get; set; }
        public int QuoteNumber { get; set; }
        public DateTime? QuoteDate { get; set; }
        public DateOnly? ExpiryDate { get; set; }
        public int PayeeId { get; set; }
        public string? PayeeName { get; set; }
        public int? SalesRepId { get; set; }
        public string? SalesRepName { get; set; }
        public decimal? SubTotal { get; set; }
        public decimal? TaxTotal { get; set; }
        public decimal? QuoteTotal { get; set; }
        public int StatusId { get; set; }
        public string? StatusName { get; set; }
        public string? Notes { get; set; }
        public int? SalesId { get; set; }
        public int? Enterby { get; set; }
        public DateTime CreatedAt { get; set; }
        public DateTime? UpdatedAt { get; set; }
        public int LineCount { get; set; }
    }
}
