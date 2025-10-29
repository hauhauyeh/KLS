using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class IncomingPaymentListReq : PagingRequest
    {
        public int? PayeeId { get; set; }
    }
}
