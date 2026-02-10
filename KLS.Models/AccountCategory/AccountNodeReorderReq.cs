using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class AccountNodeReorderReq
    {
        public int Id { get; set; }

        public string Type { get; set; } // "Category" or "Account"

        public string Direction { get; set; } // "Up" or "Down"
    }
}
