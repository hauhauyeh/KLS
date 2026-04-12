using System;

namespace KLS.Models
{
    public class RefundQueueRow
    {
        public int CustomerPaymentSourceUseId { get; set; }

        public int CustomerPaymentId { get; set; }

        public int PayeeId { get; set; }

        public string? PayeeName { get; set; }

        public int SourcePaymentNumber { get; set; }

        public DateOnly? PaymentDate { get; set; }

        public decimal ReservedAmount { get; set; }

        public string? ReferenceId { get; set; }

        public string? Notes { get; set; }
    }
}
