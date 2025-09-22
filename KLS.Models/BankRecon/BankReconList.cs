using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class BankReconList
    {
        public string? AccountType { get; set; }

        public ICollection<ReconAccount>? ReconAccounts { get; set; }

        public int? Total
        {
            get
            {
                return ReconAccounts?.Sum(c => c.BankRecons?.Count);
            }
        }

        public class ReconAccount
        {
            public string? AccountType { get; set; }

            public string? AccountName { get; set; }

            public DateOnly? MaxStmtDate { get; set; }

            public ICollection<BankRecon>? BankRecons { get; set; }
        }
    }
}
