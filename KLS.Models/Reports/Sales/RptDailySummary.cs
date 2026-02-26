using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models.Reports
{
    public class RptDailySummary
    {
        public string? ShipRoute { get; set; }

        public string? TruckNumber { get; set; }
        public string? Driver { get; set; }
        public string? Loader { get; set; }
        public string? Checker { get; set; }
        public string? Officer { get; set; }

        public List<RptDailySummaryRow>? Invoices { get; set; }

        public ICollection<SalesRouteDetail>? ReturnItems { get; set; }
    }
}
