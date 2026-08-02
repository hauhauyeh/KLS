namespace KLS.Models
{
    public class PurchaseOrderEmailPdfResult
    {
        public string DeliveryStatus { get; set; } = "";

        public string Message { get; set; } = "";

        public string? To { get; set; }

        public string? DocumentNumber { get; set; }

        public int AttachmentCount { get; set; }

        public string? ErrorMessage { get; set; }
    }
}
