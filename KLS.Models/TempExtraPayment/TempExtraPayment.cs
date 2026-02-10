using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class TempExtraPayment
    {
        [Key]
        public int TempExtraPaymentId { get; set; }

        public int EmpId { get; set; }

        public int CustomerPaymentId { get; set; }

        public int PayeeId { get; set; }

        public decimal? ExtraAmount { get; set; }

        public bool AsCredit { get; set; }

        public bool AsIncome { get; set; }

        public bool AsCCMemo { get; set; }

        [NotMapped]
        public string? PayeeName { get; set; }
    }
}
