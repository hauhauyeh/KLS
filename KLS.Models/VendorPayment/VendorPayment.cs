using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class VendorPayment
    {
        public VendorPayment()
        {
            this.CreatedAt = DateTime.UtcNow;
        }

        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public int VendorPaymentId { get; set; }

        public int PaymentNumber { get; set; }

        public string PaymentType { get; set; }

        public int PayeeId { get; set; }

        public DateOnly? PaymentDate { get; set; }

        public string? PaymentMethod { get; set; }

        public string? ReferenceId { get; set; }

        public string? FromAccount { get; set; }

        public decimal? PaymentAmount { get; set; }

        public string? Notes { get; set; }

        public bool IsLocked { get; set; }

        public DateOnly? MailDate { get; set; }

        public DateOnly? BankDate { get; set; }

        public DateOnly? PrintDate { get; set; }

        public bool IsVoid { get; set; }

        public int? VoidBy { get; set; }

        public DateTime? VoidAt { get; set; }

        public DateTime? CreatedAt { get; set; }

        public DateTime? UpdatedAt { get; set; }
    }
}
