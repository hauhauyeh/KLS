namespace KLS.Models
{
    /// <summary>
    /// One candidate open invoice - or the payer's credit memo - for a pending money-in
    /// bank feed row. Projected from BankFeed_GetOpenInvoices. Credit memos carry a
    /// negative AmountDue and apply in full or not at all.
    /// </summary>
    public class BankFeedOpenInvoice
    {
        public int SalesId { get; set; }

        public int SalesNumber { get; set; }

        public int PayeeId { get; set; }

        public string? CustomerName { get; set; }

        public string? BillName { get; set; }

        public DateOnly SalesDate { get; set; }

        public DateOnly? DueDate { get; set; }

        public decimal SalesTotal { get; set; }

        /// <summary>The open balance. Apply + ShortDiscount are measured against this.</summary>
        public decimal AmountDue { get; set; }

        public bool IsCreditMemo { get; set; }
    }
}
