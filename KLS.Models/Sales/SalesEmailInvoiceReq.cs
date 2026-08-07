namespace KLS.Models
{
    public class SalesEmailInvoiceReq
    {
        public string? Subject { get; set; }

        public string? RecipientEmail { get; set; }

        public bool IsRevised { get; set; }
    }
}
