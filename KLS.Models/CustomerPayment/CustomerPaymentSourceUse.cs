using System;
using System.ComponentModel.DataAnnotations;

namespace KLS.Models
{
    public class CustomerPaymentSourceUse
    {
        [Key]
        public int CustomerPaymentSourceUseId { get; set; }

        public int CustomerPaymentId { get; set; }

        public int SourcePaymentNumber { get; set; }

        public string? UseType { get; set; }

        public decimal Amount { get; set; }

        public int? RefundPaymentId { get; set; }

        public DateTime? RefundedAt { get; set; }

        public DateTime CreatedAt { get; set; }
    }
}
