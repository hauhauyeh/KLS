using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations.Schema;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class TransactionDetail
    {
        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public Int64 TxDetailId { get; set; }

        public Int64 TxId { get; set; }

        public int? SrcDetailId { get; set; }

        public string? AccountCode { get; set; }

        public int? PayeeId { get; set; }

        public string? ItemCode { get; set; }

        public decimal? Qty { get; set; }

        public decimal? Price { get; set; }

        public decimal? BillQty { get; set; }

        public decimal? CloQty { get; set; }

        public decimal? InvValue { get; set; }

        public decimal? AvgCost { get; set; }

        public decimal? Amount { get; set; }

        public decimal? CrDeAmount { get; set; }

        public decimal? DebitAmt { get { return (CrDeAmount < 0) ? Math.Abs(CrDeAmount ?? 0) : 0; } }

        public decimal? CreditAmt { get { return (CrDeAmount > 0) ? CrDeAmount : 0; } }

        public string? Notes { get; set; }
    }
}
