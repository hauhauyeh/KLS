using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class ItemSearchReq
    {
        public string? Term { get; set; }

        public bool IsActiveOnly { get; set; }
    }
}
