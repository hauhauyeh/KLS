using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class TempVendorPayment
    {
        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public int TempVPId { get; set; }

        public int EmpId { get; set; }

        public int PayeeId { get; set; }

        public int VendorPaymentId{ get; set; }

        public int PurchaseId { get; set; }

        public decimal? AmountDue { get; set; }

        public decimal? PaymentApplied { get; set; }

        public decimal? DiscountApplied { get; set; }

        public string? Notes { get; set; }

        public bool IsApplied { get; set; }

        [ForeignKey("PurchaseId")]
        public virtual Purchase? Purchase { get; set; }

        [NotMapped]
        public decimal? LeaveShort
        {
            get
            {
                return IsApplied ? (AmountDue - PaymentApplied - DiscountApplied) : 0;
            }
        }
    }
}
