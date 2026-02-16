using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class Account
    {
        public Account()
        {
            this.CreatedAt = DateTime.UtcNow;
        }

        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public int AccountId { get; set; }

        //public int AccountTypeId { get; set; }

        public int AccountCategoryId { get; set; }

        public string? TypeName { get; set; }

        public int SortOrder { get; set; }

        public bool IsAccountDebit { get; set; }

        public string? AccountCode { get; set; }

        public string? AccountName { get; set; }

        public string? AccountNumber { get; set; }

        public string? Description { get; set; }

        public decimal? AccountBalance { get; set; }

        public int? LastCheckNumber { get; set; }

        public string? RoutingNumber { get; set; }

        public string? BankAccountNumber { get; set; }

        public decimal? OpenBalance { get; set; }

        public bool Inactive { get; set; }

        public bool IsDefaultAccount { get; set; }

        public DateTime? CreatedAt { get; set; }

        public DateTime? UpdatedAt { get; set; }


        [ForeignKey("AccountCategoryId")]
        public virtual AccountCategory? AccountCategory { get; set; }
    }
}
