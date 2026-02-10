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

        public int? FromAccountId { get; set; }

        public decimal? PaymentAmount { get; set; }

        public string? Notes { get; set; }

        public bool IsLocked { get; set; }

        public DateOnly? MailDate { get; set; }

        public DateOnly? BankDate { get; set; }

        public DateOnly? PrintDate { get; set; }

        public bool IsPrinted { get { return PrintDate.HasValue; } }

        public bool IsVoid { get; set; }

        public int? VoidBy { get; set; }

        public DateTime? VoidAt { get; set; }

        public bool IsReturn1 { get; set; }

        public string? ReturnType1 { get; set; }

        public DateOnly? ReturnDate1 { get; set; }

        public int? FeeAccountId1 { get; set; }

        public decimal? FeeAmount1 { get; set; }

        public bool IsRedeposit { get; set; }

        public bool IsReturn2 { get; set; }

        public string? ReturnType2 { get; set; }

        public DateOnly? ReturnDate2 { get; set; }

        public int? FeeAccountId2 { get; set; }

        public decimal? FeeAmount2 { get; set; }

        public int? AccountId1 { get; set; }

        public int? AccountId2 { get; set; }

        public int? AccountId3 { get; set; }

        public int? AccountId4 { get; set; }

        public decimal? Amount1 { get; set; }

        public decimal? Amount2 { get; set; }

        public decimal? Amount3 { get; set; }

        public decimal? Amount4 { get; set; }

        public DateTime? CreatedAt { get; set; }

        public DateTime? UpdatedAt { get; set; }
    }
}
