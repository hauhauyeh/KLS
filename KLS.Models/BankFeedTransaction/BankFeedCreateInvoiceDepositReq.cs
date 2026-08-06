namespace KLS.Models
{
    /// <summary>
    /// Phase 2b: receive selected open invoices (and credit memos) as one CustomerPayment
    /// wrapped in one Deposit, from a pending money-in bank feed row. PaymentDate and
    /// DepositDate are deliberately absent - both take the bank row's PostedDate.
    /// </summary>
    public class BankFeedCreateInvoiceDepositReq
    {
        public long BankFeedTransactionId { get; set; }

        public int PayeeId { get; set; }

        public string PaymentMethod { get; set; } = "CHECK";

        public string? ReferenceId { get; set; }

        public List<BankFeedInvoiceLineReq> Lines { get; set; } = new();

        /// <summary>Bank-side difference: 'None' | 'BankFee' | 'Rounding' | 'Account'.</summary>
        public string DifferenceKind { get; set; } = "None";

        /// <summary>Required when DifferenceKind = 'Account'.</summary>
        public int? DifferenceAccountId { get; set; }

        /// <summary>Required when DifferenceKind is not 'None'.</summary>
        public string? DifferenceMemo { get; set; }
    }

    /// <summary>
    /// One selected invoice or credit memo. A credit memo's ApplyAmount is its full
    /// (negative) AmountDue and its ShortDiscount is always 0.
    /// </summary>
    public class BankFeedInvoiceLineReq
    {
        public int SalesId { get; set; }

        public decimal ApplyAmount { get; set; }

        public decimal ShortDiscount { get; set; }
    }
}
