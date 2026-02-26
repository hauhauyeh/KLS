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

        public int TFNumber { get; set; }

        public string? TFType { get; set; }

        public DateOnly? TFDate { get; set; }

        public int? FromAccountId { get; set; }

        public int? ToAccountId { get; set; }

        public string? ReferenceId { get; set; }

        public decimal? TransferAmount { get; set; }

        public int? CashbackAccountId { get; set; }

        public decimal? CashbackAmount { get; set; }

        public int? CCFeeAccountId { get; set; }

        public decimal? CCFeeAmount { get; set; }

        public decimal? RoundingOff { get; set; }

        public bool IsLocked { get; set; }

        public string? Notes { get; set; }

        public DateTime CreatedAt { get; set; }

        public DateTime? UpdatedAt { get; set; }
    }
}
