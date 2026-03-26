using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class VendorPaymentAdvanceReq
    {
        public int PurchaseId { get; set; }

        public int VendorPaymentId { get; set; }

        public DateOnly? PaymentDate { get; set; }

        public string? PaymentMethod { get; set; }

        public string? ReferenceId { get; set; }

        public int FromAccountId { get; set; }

        public decimal PaymentAmount { get; set; }

        public string? Notes { get; set; }
    }
}
