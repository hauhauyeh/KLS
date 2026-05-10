using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class TempPaymentReq
    {
        public int PayeeId { get; set; }

        public int PaymentId { get; set; }

        public string? PaymentType { get; set; }

        public bool AllowFutureInvoices { get; set; }

        public int? TempId { get; set; }
    }
}
