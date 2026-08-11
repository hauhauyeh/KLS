using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace KLS.Models
{
    public class SalesQuote
    {
        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public int SalesQuoteId { get; set; }
        public int QuoteNumber { get; set; }
        public DateTime? QuoteDate { get; set; }
        public DateOnly? ExpiryDate { get; set; }
        public int PayeeId { get; set; }
        public int? SalesRepId { get; set; }
        public int? TermId { get; set; }
        public decimal? SubTotal { get; set; }
        public decimal? TaxableTotal { get; set; }

        [Column(TypeName = "decimal(18,4)")]
        public decimal? TaxPercent { get; set; }
        public decimal? TaxTotal { get; set; }
        public decimal? QuoteTotal { get; set; }
        public int StatusId { get; set; }
        public string SalesQuoteType { get; set; } = "NormalSalesQuote";
        public string? Notes { get; set; }
        public int? SalesId { get; set; }
        public int? Enterby { get; set; }
        public int? Updateby { get; set; }
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
        public DateTime? UpdatedAt { get; set; }
    }
}
