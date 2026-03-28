using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class VendorPaymentOpenAdvance
    {
        [Key]
        public int VendorPaymentId { get; set; }

        public int PaymentNumber { get; set; }

        public DateOnly? PaymentDate { get; set; }

        public string? PaymentMethod { get; set; }

        public string? ReferenceId { get; set; }

        public string? FromAccount { get; set; }

        public decimal PaymentAmount { get; set; }

        public decimal? UnappliedAmount { get; set; }
    }
}
