using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class BankRecon
    {
        public BankRecon()
        {
            this.CreatedAt = DateTime.UtcNow;
        }

        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public int BankReconId { get; set; }

        public int? AccountId { get; set; }

        public DateOnly? StatementDate { get; set; }

        public decimal? StatementBalance { get; set; }

        public decimal? SystemBalance { get; set; }

        public decimal? BeginningBalance { get; set; }

        public decimal? EndingBalance { get; set; }

        public decimal? DifferenceAmount { get; set; }

        public bool IsReconciled { get; set; }

        public string? Notes { get; set; }

        public DateTime CreatedAt { get; set; }

        public DateTime? UpdatedAt { get; set; }
    }
}
