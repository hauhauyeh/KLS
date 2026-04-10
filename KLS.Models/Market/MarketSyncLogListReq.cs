using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class MarketSyncLogListReq : PagingRequest
    {
        public int? MarketAccountId { get; set; }
        public string? SyncType { get; set; }
        public bool? Success { get; set; }
    }
}
