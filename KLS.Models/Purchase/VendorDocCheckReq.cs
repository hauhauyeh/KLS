using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class VendorDocCheckReq
    {
        public int PayeeId { get; set; }

        public string? VendorDocNumber { get; set; }
    }
}
