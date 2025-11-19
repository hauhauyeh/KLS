using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class TempDepositList
    {
        [Key]
        public int TempTFId { get; set; }

        public string? PayeeName { get; set; }

        public DateOnly? PaymentDate { get; set; }

        public string? PaymentMethod { get; set; }

        public string? ReferenceId { get; set; }

        public decimal? DepositAmount { get; set; }

        public string? Notes { get; set; }

        public bool IsApplied { get; set; }
    }
}
