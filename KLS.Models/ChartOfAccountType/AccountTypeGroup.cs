using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class AccountTypeGroup
    {
        public string? AccountType { get; set; }

        public IEnumerable<ChartOfAccountType>? DetailTypes { get; set; }
    }
}
