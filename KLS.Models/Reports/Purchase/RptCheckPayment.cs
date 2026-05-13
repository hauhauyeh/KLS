using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models.Reports
{
    public class RptCheckPayment
    {
        public RptCheckPrint? VendorInfo { get; set; }

        public ICollection<RptCheckPrintDetail>? BillDetails { get; set; }

        public string? BankLogo { get; set; }

        public string? AmtInWords { get; set; }
    }
}
