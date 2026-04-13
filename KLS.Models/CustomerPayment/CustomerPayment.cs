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

        public int? FromAccountId { get; set; }

        public string? ReferenceId { get; set; }

        public decimal? PaymentAmount { get; set; }

        public string? Notes { get; set; }

        public bool IsLocked { get; set; }

        public decimal? PaymentApplied { get; set; }

        public decimal? UnappliedAmount { get; set; }

        public decimal? AsIncome { get; set; }

        public int? VendorPaymentId { get; set; }

        [NotMapped]
        public decimal? ExtraDispositionAmount { get; set; }

        [NotMapped]
        public string? ExtraDisposition { get; set; }

        public bool IsBadDebt { get; set; }

        public string? CardType { get; set; }

        public string? Last4 { get; set; }

        public bool IsReturned { get; set; }

        public string? ReturnType { get; set; }

        public DateOnly? ReturnDate { get; set; }

        public int? FeeAccountId { get; set; }

        public decimal? FeeAmount { get; set; }

        public string? ReturnNotes { get; set; }

        public int? ReturnSalesId { get; set; }

        public int? AccountId1 { get; set; }

        public int? AccountId2 { get; set; }

        public int? AccountId3 { get; set; }

        public int? AccountId4 { get; set; }

        public decimal? Amount1 { get; set; }

        public decimal? Amount2 { get; set; }

        public decimal? Amount3 { get; set; }

        public decimal? Amount4 { get; set; }

        public DateTime CreatedAt { get; set; }

        public DateTime? UpdatedAt { get; set; }

        [ForeignKey("PayeeId")]
        public virtual Payee? Payee { get; set; }


        [ForeignKey("CustomerPaymentId")]
        public virtual List<CustomerPaymentDetail>? PaymentDetails { get; set; }
    }
}
