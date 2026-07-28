namespace KLS.Models
{
    /// <summary>
    /// Create a VendorPayment from a pending money-out bank feed row and match the row to it.
    /// </summary>
    /// <remarks>
    /// Deliberately absent, because the server owns them:
    ///   PaymentDate          - always the bank row's PostedDate
    ///   DifferenceResolution - derived from the amounts
    ///   Notes                - built from the bank description
    ///   DifferenceAccountId  - discounts always post to '@IDR'
    /// </remarks>
    public class BankFeedCreateVendorPaymentReq
    {
        public long BankFeedTransactionId { get; set; }

        public int PayeeId { get; set; }

        /// <summary>ACH, E-CHECK, CASH, HANDWRITE CHECK or CREDIT CARD. CHECK is not supported.</summary>
        public string? PaymentMethod { get; set; }

        public string? ReferenceId { get; set; }

        public List<BankFeedOpenBillLineReq> Lines { get; set; } = new();

        /// <summary>Required when any line carries a discount.</summary>
        public string? DifferenceMemo { get; set; }
    }

    /// <summary>One selected open bill and how much of the payment goes to it.</summary>
    public class BankFeedOpenBillLineReq
    {
        public int PurchaseId { get; set; }

        /// <summary>Cash applied. The sum across lines must equal the absolute bank amount.</summary>
        public decimal ApplyAmount { get; set; }

        /// <summary>Written down to close the remaining balance. Zero for a partial payment.</summary>
        public decimal DiscountAmount { get; set; }
    }
}
