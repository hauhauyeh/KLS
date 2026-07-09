namespace KLS.Models
{
    // Result of converting a quote to an order (one-click auto-create).
    // Carries the newly created Sales order identity so the UI can toast
    // the order number and mark the quote row Converted.
    public class SalesQuoteConvertResult
    {
        public int SalesId { get; set; }
        public int SalesNumber { get; set; }
    }
}
