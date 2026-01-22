using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models.Reports
{
    public class RptCustStmt
    {
        public Payee? Payee { get; set; }

        public bool IsPromotionEnabled { get; set; }

        public List<RptCustStmtDetail>? Details { get; set; }

        public string? EmailNotes { get; set; }

        public List<CustomerPayment>? AvailableCredit { get; set; }
    }
}
