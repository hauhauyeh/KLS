using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class ReportRequest
    {
        public DateOnly? StartDate { get; set; }

        public DateOnly? EndDate { get; set; }

        public string? SortField { get; set; }

        public string? SortOrder { get; set; }

        public string? Search { get; set; }

        public int? SalesRepId { get; set; }

        public int? PayeeId { get; set; }
    }
}
