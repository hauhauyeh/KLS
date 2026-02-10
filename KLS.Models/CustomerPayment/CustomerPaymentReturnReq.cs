using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class CustomerPaymentReturnReq
    {
        public int CustomerPaymentId { get; set; }

        public string? ReturnType { get; set; }

        public DateOnly? ReturnDate { get; set; }

        public int? FeeAccountId { get; set; }

        public decimal? FeeAmount { get; set; }

        public decimal? NSFFee { get; set; }
    }
}
