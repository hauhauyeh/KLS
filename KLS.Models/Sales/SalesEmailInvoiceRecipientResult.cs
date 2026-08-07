namespace KLS.Models
{
    public class SalesEmailInvoiceRecipientResult
    {
        public string? RecipientEmail { get; set; }

        public int? PayeeId { get; set; }

        public string? PayeeName { get; set; }

        public string Source { get; set; } = "";
    }
}
