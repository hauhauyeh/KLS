using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class VendorPaymentReturnReq
    {
        public int VendorPaymentId { get; set; }

        public string? ReturnType { get; set; }

        public DateTime? ReturnDate { get; set; }

        public int? FeeAccountId { get; set; }

        public decimal? FeeAmount { get; set; }

        public bool IsRedeposit { get; set; }
    }
}
