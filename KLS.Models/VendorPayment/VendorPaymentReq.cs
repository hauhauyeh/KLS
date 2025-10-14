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

        public int? FromAccountId { get; set; }

        public string? PaymentMethod { get; set; }
    }
}
