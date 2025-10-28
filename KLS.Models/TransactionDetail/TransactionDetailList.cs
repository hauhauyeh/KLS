using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class TransactionDetailList
    {
        [Key]
        public Int64 TxDetailId { get; set; }

        public Int64 TxId { get; set; }

        public string? AccountName { get; set; }

        public string? ItemName { get; set; }

        public decimal? Amount { get; set; }

        public decimal? CrDeAmount { get; set; }

        public decimal? DebitAmt { get { return (CrDeAmount < 0) ? Math.Abs(CrDeAmount ?? 0) : 0; } }

        public decimal? CreditAmt { get { return (CrDeAmount > 0) ? CrDeAmount : 0; } }
    }
}
