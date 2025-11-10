using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class TempVendorPaymentListReq
    {
        public int EmpId { get; set; }

        public int PayeeId { get; set; }

        public int VendorPaymentId { get; set; }

        public string? PaymentType { get; set; }
    }
}
