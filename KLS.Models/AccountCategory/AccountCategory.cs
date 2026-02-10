using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class AccountCategory
    {
        [Key]
        public int AccountCategoryId { get; set; }

        public int? ParentId { get; set; }

        [Required]
        public string CategoryName { get; set; } = string.Empty;

        [Required]
        public string ClassCode { get; set; } = string.Empty; // A, L, Q, I, X, C

        public string ClassName { get; set; } = string.Empty;

        [Required]
        [MaxLength(1)]
        public string NormalSide { get; set; } = string.Empty; // D or C

        public int SortOrder { get; set; }

        [ForeignKey("ParentId")]
        public virtual AccountCategory? ParentCategory { get; set; }

        public virtual ICollection<AccountCategory> ChildCategories { get; set; } = new List<AccountCategory>();

        public virtual ICollection<Account> Accounts { get; set; } = [];

    }
}
