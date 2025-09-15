using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class PayeeSearchReq
    {
        public string? Term { get; set; }

        public bool IsActiveOnly { get; set; }

        public bool IsSearchSales { get; set; }
    }
}
