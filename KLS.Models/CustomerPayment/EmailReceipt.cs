using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class EmailReceipt
    {
        public CustomerPayment? Payment { get; set; }

        public Payee? Payee { get; set; }

        public Company? Company { get; set; }
    }
}
