using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class EmailLogReq : PagingRequest
    {
        public string? Category { get; set; }

        public string? EmailType { get; set; }

        public string? DeliveryStatus { get; set; }
    }
}
