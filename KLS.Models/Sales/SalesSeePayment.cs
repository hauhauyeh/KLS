using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class SalesSeePayment
    {
        public Sales? Sales { get; set; }

        public ICollection<CustomerPayment>? CustomerPayments { get; set; }
    }
}
