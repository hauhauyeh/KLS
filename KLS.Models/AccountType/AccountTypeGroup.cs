using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class AccountTypeGroup
    {
        public string? TypeName { get; set; }

        public IEnumerable<AccountType>? DetailTypes { get; set; }
    }
}
