using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class POCopyToBillReq
    {
        public int PurchaseId { get; set; }

        public string? ItemsJson { get; set; }

        public string? ShipmentIds { get; set; }

        public string? OrderMode { get; set; }
    }
}
