using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class LiabilityList
    {
        [Key]
        public int PayeeId { get; set; }

        public string? PayeeName { get; set; }

        public DateOnly? StartDate { get; set; }

        public decimal? OpeningBalance { get; set; }

        public DateOnly? LastPaymentDate { get; set; }

        public decimal? LastPaymentAmount { get; set; }

        public decimal? BalanceRemaining { get; set; }
    }
}
