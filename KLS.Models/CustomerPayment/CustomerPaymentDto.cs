using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class CustomerPaymentDto
    {
        [Key]
        public int CustomerPaymentId { get; set; }

        public int PaymentNumber { get; set; }

        public string? PaymentType { get; set; }

        public int PayeeId { get; set; }

        public string? PayeeName { get; set; }

        public DateOnly? PaymentDate { get; set; }

        public string? PaymentMethod { get; set; }

        public string? ReferenceId { get; set; }

        public decimal? PaymentAmount { get; set; }

        public decimal? PaymentApplied { get; set; }

        public decimal? UnappliedAmount { get; set; }

        public string? Notes { get; set; }

        public bool IsLocked { get; set; }

        public bool IsReturned { get; set; }
    }
}
