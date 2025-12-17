using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class DepositList
    {
        [Key]
        public int TFId { get; set; }

        public int TFNumber { get; set; }

        public DateTime? TFDate { get; set; }

        public string? ToAccount { get; set; }

        public decimal? TransferAmount { get; set; }

        public decimal? CashBackAmount { get; set; }

        public string? CashBackAccount { get; set; }

        public decimal? CCFeeAmount { get; set; }

        public bool IsLocked { get; set; }
    }
}
