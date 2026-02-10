using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class AccountFlatTree
    {
        [Key]
        public string UniqueId => $"{Type}_{Id}";

        public int Id { get; set; }

        public string Type { get; set; } = string.Empty; // "Category" or "Account"

        public int? ParentId { get; set; }

        public string Name { get; set; } = string.Empty; //AccountName and CategoryName

        public string AccountCode { get; set; } = string.Empty;

        public string ClassCode { get; set; } = string.Empty;

        public string NormalSide { get; set; } = string.Empty;

        public int SortOrder { get; set; }

        public bool IsAccountDebit { get; set; }

        public bool IsDefaultAccount { get; set; }


        public bool HasChild { get; set; }

        public List<AccountFlatTree> Children { get; set; } = [];
    }
}
