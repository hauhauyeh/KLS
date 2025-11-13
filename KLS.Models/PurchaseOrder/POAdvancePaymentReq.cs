using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class POAdvancePaymentReq
    {
        public int POId { get; set; }

        public DateOnly? PaymentDate { get; set; }

        public string? PaymentMethod { get; set; }

        public int FromAccountId { get; set; }

        public decimal? AdvanceTotal { get; set; }
    }
}
