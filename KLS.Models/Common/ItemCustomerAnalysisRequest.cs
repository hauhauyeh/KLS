namespace KLS.Models
{
    public class ItemCustomerAnalysisRequest : ReportRequest
    {
        public int ItemId { get; set; }

        public string? ItemName { get; set; }
    }
}
