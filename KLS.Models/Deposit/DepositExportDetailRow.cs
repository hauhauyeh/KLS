using System;

namespace KLS.Models
{
    public class DepositExportDetailRow
    {
        public int TFId { get; set; }

        public int TFNumber { get; set; }

        public DateOnly? TFDate { get; set; }

        public string? ToAccount { get; set; }

        public decimal? TransferAmount { get; set; }

        public string? CashBackAccount { get; set; }

        public decimal? CashBackAmount { get; set; }

        public decimal? CCFeeAmount { get; set; }

        public bool IsLocked { get; set; }

        public int? TFDetailId { get; set; }

        public int? CustomerPaymentId { get; set; }

        public int? PaymentDetailId { get; set; }

        public int? PaymentNumber { get; set; }

        public DateOnly? PaymentDate { get; set; }

        public string? PaymentMethod { get; set; }

        public string? PaymentReference { get; set; }

        public string? Customer { get; set; }

        public decimal? PaymentAmount { get; set; }

        public decimal? DepositDetailAmount { get; set; }

        public int? InvoiceNumber { get; set; }

        public string? SalesDocNum { get; set; }

        public DateTime? InvoiceDate { get; set; }

        public decimal? InvoiceTotal { get; set; }

        public decimal? PaymentApplied { get; set; }

        public decimal? DiscountApplied { get; set; }

        public decimal? PaymentDiscount { get; set; }

        public decimal? ShortDiscount { get; set; }

        public decimal? OtherDiscount { get; set; }

        public string? DetailRole { get; set; }

        public string? DetailNotes { get; set; }
    }
}
