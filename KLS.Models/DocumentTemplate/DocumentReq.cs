using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class DocumentReq
    {
        public DateOnly? ShipDate { get; set; }

        public string? ShipRoute { get; set; }

        public int? SalesId { get; set; }

        public int? SalesNumber { get; set; }

        public bool IsPrint { get; set; }
    }
}
