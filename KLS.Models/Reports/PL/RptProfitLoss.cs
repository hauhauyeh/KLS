using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models.Reports
{
    public class RptProfitLoss
    {
        public string? GroupName { get; set; }

        public string? AccountCode { get; set; }

        public decimal? GroupTotal { get; set; }

        public decimal? GrossMargin { get; set; }

        public List<RptProfitLoss>? Children { get; set; }
    }
}
