using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class AccountList
    {
        public string? AccountClass { get; set; }

        public ICollection<AccountDTO>? Accounts { get; set; }

        public int Total { get { return Accounts.Count(); } }
    }
}
