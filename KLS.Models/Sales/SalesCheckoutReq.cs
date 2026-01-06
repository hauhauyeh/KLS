using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class SalesCheckoutReq
    {
        public int SalesId { get; set; }

        public int PayeeId { get; set; }

        public DateOnly? ShipDate { get; set; }

        public string? ShipRoute { get; set; }

        public string? Instruction { get; set; }

        public int? StageId { get; set; }
    }
}
