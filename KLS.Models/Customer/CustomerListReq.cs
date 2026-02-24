using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class CustomerListReq : PagingRequest
    {
        public string? Content { get; set; }

        public string? Sortby { get; set; }

        public string? Category { get; set; }
    }
}
