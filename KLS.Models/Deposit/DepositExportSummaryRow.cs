using System;

namespace KLS.Models
{
    public class DepositExportSummaryRow
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

        public int PaymentCount { get; set; }

        public int DetailLineCount { get; set; }
    }
}
