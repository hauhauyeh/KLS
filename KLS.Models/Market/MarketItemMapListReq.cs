using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class MarketItemMapListReq : PagingRequest
    {
        public int? MarketAccountId { get; set; }
        public string? MappingStatus { get; set; }
        public string? LastSyncStatus { get; set; }
    }
}
