using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class Payroll
    {
        [Key]
        public int VendorPaymentId { get; set; }

        public int PaymentNumber { get; set; }

        public DateOnly? PaymentDate { get; set; }

        public string? PaymentMethod { get; set; }

        public int? FromAccountId { get; set; }

        public string? ReferenceId { get; set; }

        public bool IsLocked { get; set; }

        public string? Notes { get; set; }

        public DateOnly? PayPeriodStart { get; set; }

        public DateOnly? PayPeriodEnd { get; set; }
    }
}
