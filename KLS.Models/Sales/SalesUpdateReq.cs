using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class SalesUpdateReq
    {
        public int SalesId { get; set; }


        public string? ShipRoute { get; set; }

        public string? Instruction { get; set; }

        public string? CustPONumber { get; set; }
    }
}
