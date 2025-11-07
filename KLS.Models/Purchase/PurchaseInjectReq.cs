using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class PurchaseInjectReq
    {
        public int PayeeId { get; set; }

        public int PurchaseId { get; set; }

        public bool IsPayNow { get; set; }
    }
}
