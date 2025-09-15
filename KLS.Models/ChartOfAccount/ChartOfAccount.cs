using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class ChartOfAccount
    {
        public ChartOfAccount()
        {
            this.CreatedAt = DateTime.UtcNow;
        }

        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public int AccountId { get; set; }

        public int AccountTypeId { get; set; }

        public int? ParentAccountId { get; set; }

        public string? AccountNumber { get; set; }

        public bool IsAccountDebit { get; set; }

        public string? AccountCode { get; set; }

        public string? AccountName { get; set; }

        public string? AccountDesc { get; set; }

        public decimal? AccountBalance { get; set; }

        public int? LastCheckNumber { get; set; }

        public string? RoutingNumber { get; set; }

        public string? BankAccountNumber { get; set; }

        public decimal? OpenBalance { get; set; }

        public bool IsInactive { get; set; }

        public bool IsDefaultAccount { get; set; }

        public DateTime? CreatedAt { get; set; }

        public DateTime? UpdatedAt { get; set; }

    }
}
