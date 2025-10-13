using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class CustomerPayment
    {
        public CustomerPayment()
        {
            this.CreatedAt = DateTime.UtcNow;
        }

        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public int CustomerPaymentId { get; set; }

        public int PaymentNumber { get; set; }

        public string? PaymentType { get; set; }

        public int PayeeId { get; set; }

        public DateOnly? PaymentDate { get; set; }

        public string? PaymentMethod { get; set; }

        public string? FromAccount { get; set; }

        public string? ReferenceId { get; set; }

        public decimal? PaymentAmount { get; set; }

        public string? Notes { get; set; }

        public bool IsLocked { get; set; }

        public decimal PaymentApplied { get; set; }

        public decimal UnappliedAmount { get; set; }

        public decimal AsIncome { get; set; }

        public bool IsBadDebt { get; set; }

        public string? CardType { get; set; }

        public string? Last4 { get; set; }

        public bool IsReturned { get; set; }

        public string? ReturnType { get; set; }

        public DateOnly? ReturnDate { get; set; }

        public string? FeeAccount { get; set; }

        public decimal? FeeAmount { get; set; }

        public string? ReturnNotes { get; set; }

        public int? ReturnSalesId { get; set; }

        public DateTime? CreatedAt { get; set; }

        public DateTime? UpdatedAt { get; set; }
    }
}
