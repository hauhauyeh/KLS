using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class GeneralJournalDetail
    {
        [Key]
        public int GJDetailId { get; set; }

        public int GJId { get; set; }

        public int? AccountId { get; set; }

        //public string? AccountCode { get; set; }

        public int? PayeeId { get; set; }

        public decimal? Amount { get; set; }

        public decimal? CrDeAmount { get; set; }

        public decimal? DebitAmount { get; set; }

        public decimal? CreditAmount { get; set; }

        public string? Notes { get; set; }
    }
}
