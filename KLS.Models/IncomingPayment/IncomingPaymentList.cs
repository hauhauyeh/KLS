using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class IncomingPaymentList
    {
        [Key]
        public int? CustomerPaymentId { get; set; }

        public int? PaymentNumber { get; set; }

        public DateOnly? PaymentDate { get; set; }

        public string? PaymentMethod { get; set; }

        public string? ReferenceId { get; set; }

        public decimal? PaymentAmount{ get; set; }

        public string? PayeeName { get; set; }

        public bool? IsLocked { get; set; }

        public string? Notes { get; set; }
    }
}
