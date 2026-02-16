using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class PaymentChargeReq
    {
        public PaymentChargeReq()
        {
            PaymentAmount = 0;
        }

        public int PayeeId { get; set; }

        public string? SalesIds { get; set; }

        public int? PaymentMethodId { get; set; }

        public string? SqToken { get; set; }

        public decimal? CCFeePercent { get; set; }

        public decimal PaymentAmount { get; set; }

        public bool IsPaymentChange { get; set; }

        public PaymentMethod? PaymentMethod { get; set; }
    }
}
