using System.Collections.Generic;

namespace KLS.Models.Reports
{
    public class RptLedger
    {
        public decimal OpeningBalance { get; set; }

        public List<RptLedgerRow>? Rows { get; set; }
    }
}
