using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class TransferFundList
    {
        [Key]
        public int TFId { get; set; }

        public int TFNumber { get; set; }

        public DateOnly? TFDate { get; set; }

        public string? TFType { get; set; }

        public decimal? TransferAmount { get; set; }

        public string? ReferenceId { get; set; }

        public string? FromAccount { get; set; }

        public string? ToAccount { get; set; }

        public bool IsLocked { get; set; }

        public string? Notes { get; set; }
    }
}
