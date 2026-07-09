using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class DepositReq : PagingRequest
    {
        public int? ToAccountId { get; set; }

        // 2026-07-09: uncleared = TransferFund.IsLocked = 0
        public bool Uncleared { get; set; }
    }
}
