using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class InventoryReportRequest
    {
        public string? Search { get; set; }

        public int? CategoryId { get; set; }

        public string? Zone { get; set; }

        public bool? ShowInactive { get; set; }

        public bool? ShowExpiry { get; set; }

        public int? PayeeId { get; set; }
    }
}
