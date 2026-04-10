using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class MarketAccountListReq : PagingRequest
    {
        public string? MarketType { get; set; }
        public bool? IsActive { get; set; }
    }
}
