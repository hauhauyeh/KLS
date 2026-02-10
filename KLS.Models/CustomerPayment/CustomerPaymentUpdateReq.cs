using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class CustomerPaymentUpdateReq
    {
        public int CustomerPaymentId { get; set; }

        public string? Notes { get; set; }
    }
}
