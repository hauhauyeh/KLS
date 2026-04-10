using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class MarketOrderListReq : PagingRequest
    {
        public int? MarketAccountId { get; set; }
        public string? OrderStatus { get; set; }
        public bool? ImportedToErp { get; set; }
    }
}
