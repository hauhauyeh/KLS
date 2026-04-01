using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class SalesWebCheckoutReq
    {
        public DateOnly? ShipDate { get; set; }

        public string? ShipRoute { get; set; }

        public bool IsPickUp { get; set; }

        public string? Instruction { get; set; }

        public string? Email { get; set; }

        public string? Phone { get; set; }
    }
}
