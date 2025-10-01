using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class VendorPaymentReq : PagingRequest
    {
        public int? PayeeId { get; set; }

        public string? FromAccount { get; set; }

        public string? PaymentMethod { get; set; }
    }
}
