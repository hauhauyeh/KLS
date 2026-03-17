using System.ComponentModel.DataAnnotations;

namespace KLS.Models.Reports
{
    public class RptCustPayment
    {
        [Key]
        public int CustomerPaymentId { get; set; }

        public DateOnly? PaymentDate { get; set; }

        public string? PaymentMethod { get; set; }

        public string? ReferenceId { get; set; }

        public decimal? PaymentAmount { get; set; }

        public string? PayeeName { get; set; }

        public string? Notes { get; set; }
    }
}
