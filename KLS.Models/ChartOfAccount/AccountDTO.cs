using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class AccountDTO
    {
        public int AccountId { get; set; }

        public string? AccountType { get; set; }

        public string? CatName { get; set; }

        public string? AccountCode { get; set; }

        public string? AccountName { get; set; }

        public bool IsInactive { get; set; }
    }
}
