using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class GeneralJournal
    {
        public GeneralJournal()
        {
            this.CreatedAt = DateTime.UtcNow;
        }

        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public int GJId { get; set; }

        public int GJNum { get; set; }

        public DateOnly? GJDate { get; set; }

        public decimal? TotalDebitAmount { get; set; }

        public decimal? TotalCreditAmount { get; set; }

        public string? Notes { get; set; }

        public bool IsLocked { get; set; }

        public bool IsNetIncome { get; set; }

        public DateTime CreatedAt { get; set; }

        public DateTime? UpdatedAt { get; set; }
    }
}
