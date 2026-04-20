using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class PayrollUpdateReq
    {
        public int VendorPaymentId { get; set; }

        public string? ReferenceId { get; set; }
    }
}
