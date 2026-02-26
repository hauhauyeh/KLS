using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models.Reports
{
    public class RptSalesYearlyRow
    {
        public DateOnly? SalesMonth { get; set; }

        public DateOnly? SalesMonthName { get; set; }

        public int? AccountId { get; set; }

        public string? AccountName { get; set; }

        public decimal? Y1 { get; set; }

        public decimal? Y2 { get; set; }

        public decimal? Y3 { get; set; }

        public decimal? Y1Percent { get; set; }

        public decimal? Y2Percent { get; set; }
    }
}
