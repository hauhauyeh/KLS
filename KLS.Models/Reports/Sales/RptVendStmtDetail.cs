using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;

namespace KLS.Models.Reports
{
    public class RptVendStmtDetail
    {
        [Key]
        public string? ArrivalMonth { get; set; }

        public ICollection<Purchase>? Purchases { get; set; }

        public decimal? MonthTotal
        {
            get
            {
                return Purchases?.Sum(p => p.AmountDue);
            }
        }
    }
}
