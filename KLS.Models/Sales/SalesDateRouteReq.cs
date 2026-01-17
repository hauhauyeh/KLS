using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class SalesDateRouteReq
    {
        public DateOnly ShipDate { get; set; }

        public string? ShipRoute { get; set; }
    }
}
