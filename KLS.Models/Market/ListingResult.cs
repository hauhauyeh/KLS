using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class ListingResult
    {
        public string? Sku { get; set; }
        public string? Status { get; set; }
        public string? SubmissionId { get; set; }
        public List<ListingIssue>? Issues { get; set; }
    }

    public class ListingIssue
    {
        public string? Code { get; set; }
        public string? Message { get; set; }
        public string? Severity { get; set; }
    }
}
