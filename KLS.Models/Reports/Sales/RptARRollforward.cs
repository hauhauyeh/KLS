using System.ComponentModel.DataAnnotations;

namespace KLS.Models.Reports
{
    public class RptARRollforward
    {
        [Key]
        public long Id { get; set; }

        public int? PayeeId { get; set; }

        public string? Customer { get; set; }

        public decimal? BeginningAR { get; set; }

        public decimal? Invoices { get; set; }

        public decimal? Payments { get; set; }

        public decimal? CreditsAdjustments { get; set; }

        public decimal? EndingAR { get; set; }
    }
}
