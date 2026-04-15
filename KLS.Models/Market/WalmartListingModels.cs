using System.Collections.Generic;

namespace KLS.Models
{
    public class WalmartItemSubmissionResponse
    {
        public string? FeedId { get; set; }
        public string? ItemId { get; set; }
        public string? Sku { get; set; }
        public string? Status { get; set; }
    }

    public class WalmartItemStatusResponse
    {
        public string? Sku { get; set; }
        public string? PublishedStatus { get; set; }
        public string? LifecycleStatus { get; set; }
        public string? ProductName { get; set; }
        public List<WalmartItemIssue>? Issues { get; set; }
    }

    public class WalmartItemIssue
    {
        public string? Code { get; set; }
        public string? Message { get; set; }
        public string? Severity { get; set; }
    }
}
