using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models.Reports
{
    public class RptPaymentHistory
    {
        public string? PaymentMonth { get; set; }

        public ICollection<CustomerPayment>? Payments { get; set; }

        public decimal? MonthTotal => Payments?.Sum(c => c.PaymentAmount);
    }
}
