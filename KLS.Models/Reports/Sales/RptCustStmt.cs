using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models.Reports
{
    public enum StatementScope
    {
        ShipTo,
        BillTo
    }

    public class RptCustStmt
    {
        public Payee? Payee { get; set; }

        public string StatementScope { get; set; } = global::KLS.Models.Reports.StatementScope.ShipTo.ToString();

        public int? SelectedPayeeId { get; set; }

        public int? EffectiveBillToId { get; set; }

        public string? EffectiveBillToName { get; set; }

        public bool CanUseBillToStatement { get; set; }

        public decimal? StatementCurrent { get; set; }

        public decimal? Statement30 { get; set; }

        public decimal? Statement60 { get; set; }

        public decimal? Statement90 { get; set; }

        public decimal? StatementOver90 { get; set; }

        public decimal? StatementTotalDue { get; set; }

        public decimal? AccountBalance { get; set; }

        public bool IsPromotionEnabled { get; set; }

        public bool UseSalesDocNumber { get; set; }

        public List<RptCustStmtDetail>? Details { get; set; }

        public List<RptCustStmtBillToGroup>? BillToGroups { get; set; }

        public string? EmailNotes { get; set; }

        public List<CustomerPayment>? AvailableCredit { get; set; }
    }

    public class RptCustStmtBillToGroup
    {
        public int? ShipId { get; set; }

        public string? ShipToName { get; set; }

        public List<Sales>? Sales { get; set; }

        public decimal? ShipToTotal
        {
            get
            {
                return Sales?.Sum(s => s.AmountDue);
            }
        }
    }
}
