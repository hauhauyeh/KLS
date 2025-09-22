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

        public string? BankAcctCode { get; set; }

        public DateOnly? StmtDate { get; set; }

        public decimal? StmtBalance { get; set; }

        public decimal? SystemBalance { get; set; }

        public decimal? BeginBalance { get; set; }

        public decimal? ReconEndBalance { get; set; }

        public decimal? DifferenceAmount { get; set; }

        public bool IsReconed { get; set; }

        public string? Notes { get; set; }

        public DateTime? CreatedAt { get; set; }

        public DateTime? UpdatedAt { get; set; }
    }
}
