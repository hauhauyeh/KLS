using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class AmazonListingSubmissionResult
    {
        public string? Sku { get; set; }
        public string? Status { get; set; }
        public string? SubmissionId { get; set; }
        public List<AmazonListingIssue>? Issues { get; set; }
    }

    public class AmazonListingIssue
    {
        public string? Code { get; set; }
        public string? Message { get; set; }
        public string? Severity { get; set; }
    }

    public class AmazonListingStatus
    {
        public string? Sku { get; set; }
        public string? Status { get; set; }
        public List<AmazonListingSummary>? Summaries { get; set; }
        public List<AmazonListingIssue>? Issues { get; set; }
    }

    public class AmazonListingSummary
    {
        public string? MarketplaceId { get; set; }
        public string? Asin { get; set; }
        public string? ProductType { get; set; }
        public string? ItemName { get; set; }
        public string? Status { get; set; }
    }
}
