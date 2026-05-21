using System.Collections.Generic;

namespace KLS.Models.Reports
{
    public class RptVendStmt
    {
        public Payee? Payee { get; set; }

        public List<RptVendStmtDetail>? Details { get; set; }
    }
}
