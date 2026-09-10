namespace KLS.Models
{
    public class InventoryAuditReportRequest : ReportRequest
    {
        public int? ItemId { get; set; }

        public string? ItemName { get; set; }

        public string? SourceDocType { get; set; }

        public int? SourceDocNumber { get; set; }
    }
}
