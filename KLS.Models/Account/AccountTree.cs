using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class AccountTree
    {
        [Key]
        public int AccountId { get; set; }

        public string? TypeName { get; set; }

        public string? CatName { get; set; }

        public string? AccountCode { get; set; }

        public string? AccountName { get; set; }

        public int? ParentAccountId { get; set; }

        public bool IsInactive { get; set; }

        public IEnumerable<AccountTree>? ChildAccounts { get; set; }

        public bool HasChild { get { return ChildAccounts != null && ChildAccounts.Any(); } }
    }
}
