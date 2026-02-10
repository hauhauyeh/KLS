using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class SalesMergeReq
    {
        public string? SalesIds { get; set; }

        public string? SalesNumbers { get; set; }

        public string? Destination { get; set; }
    }
}
