using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class PurchaseSeePayment
    {
        public Purchase? Purchase { get; set; }

        public ICollection<VendorPaymentList>? VendorPayments { get; set; }
    }
}
