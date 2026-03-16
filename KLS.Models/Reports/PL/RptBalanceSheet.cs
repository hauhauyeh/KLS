using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models.Reports
{
    public class RptBalanceSheet
    {
        public string? GroupName { get; set; }

        public string? ClassCode { get; set; }

        public decimal? GroupTotal { get; set; }

        public List<RptBalanceSheetItem>? Items { get; set; }

        public List<RptBalanceSheet>? Children { get; set; }
    }

    public class RptBalanceSheetItem
    {
        public int? AccountId { get; set; }

        public string? AccountCode { get; set; }

        public string? AccountName { get; set; }

        public string? ClassCode { get; set; }

        public decimal? ClosingBalance { get; set; }
    }
}
