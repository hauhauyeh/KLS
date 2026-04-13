using System;

namespace KLS.Models
{
    public class IssueRefundReq
    {
        public int CustomerPaymentSourceUseId { get; set; }

        public DateOnly? PaymentDate { get; set; }

        public string? PaymentMethod { get; set; }

        public int? FromAccountId { get; set; }

        public string? ReferenceId { get; set; }

        public string? Notes { get; set; }
    }
}
