using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class ItemListReq : PagingRequest
    {
        public int? VendorId { get; set; }

        public string? Container { get; set; }
    }
}
