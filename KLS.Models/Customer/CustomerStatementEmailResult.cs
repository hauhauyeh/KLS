namespace KLS.Models
{
    public class CustomerStatementEmailResult
    {
        public bool Sent { get; set; }

        public string DeliveryStatus { get; set; } = "";

        public string Message { get; set; } = "";

        public string? RecipientEmail { get; set; }

        public int AttachmentCount { get; set; }

        public string? Error { get; set; }
    }
}
