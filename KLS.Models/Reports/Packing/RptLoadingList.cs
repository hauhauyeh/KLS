using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models.Reports
{
    public class RptLoadingList
    {
        public DateOnly? ShipDate { get; set; }

        public string? ShipRoute { get; set; }

        public int? SalesId { get; set; }

        public string? PayeeName { get; set; }

        public string? TruckNumber { get; set; }

        public int DropCount { get; set; }

        public List<RptLoadingItem>? LoadingItems { get; set; }
    }
}
