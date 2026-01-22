using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models.Reports
{
    public class RptCustStmtDetail
    {
        [Key]
        public string? ShipMonth { get; set; }

        public ICollection<Sales>? Sales { get; set; }

        public decimal? MonthTotal
        {
            get
            {
                return Sales?.Sum(s => s.AmountDue);
            }
        }
    }
}
