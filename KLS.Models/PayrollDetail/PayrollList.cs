using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class PayrollList
    {
        [Key]
        public int VendorPaymentId { get; set; }

        public int PaymentNumber { get; set; }

        public int PayeeId { get; set; }

        public DateOnly? PayrollStartDate { get; set; }

        public DateOnly? PayrollEndDate { get; set; }

        public DateOnly? PaymentDate { get; set; }

        public string? PaymentMethod { get; set; }

        public string? FromAccount { get; set; }

        public string? ReferenceId { get; set; }

        public decimal? PaymentAmount { get; set; }

        public string? PayeeName { get; set; }

        public bool IsLocked { get; set; }

        public bool IsVoid { get; set; }

        public string? Notes { get; set; }
    }
}
