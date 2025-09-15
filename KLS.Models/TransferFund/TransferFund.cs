using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class TransferFund
    {
        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public int TFId { get; set; }

        public int TFNum { get; set; }

        public string? TFType { get; set; }

        public DateTime? TFDate { get; set; }

        public string? FromAccount { get; set; }

        public string? ToAccount { get; set; }

        public string? RefNum { get; set; }

        public decimal? TransferAmount { get; set; }

        public string? CashbackAccount { get; set; }

        public decimal? CashbackAmount { get; set; }

        public string? CCFeeAccount { get; set; }

        public decimal? CCFeeAmount { get; set; }

        public decimal? RoundingOff { get; set; }

        public bool IsLocked { get; set; }

        public string? Notes { get; set; }

        public DateTime? CreatedAt { get; set; }

        public DateTime? UpdatedAt { get; set; }
    }
}
