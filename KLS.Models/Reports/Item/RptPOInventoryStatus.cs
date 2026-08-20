using System.Collections.Generic;

namespace KLS.Models.Reports
{
    public class RptPOInventoryStatus
    {
        public IEnumerable<RptInventoryStatusRow> Status { get; set; } = [];

        public IEnumerable<RptInventoryIncomingRow> Incoming { get; set; } = [];
    }
}
