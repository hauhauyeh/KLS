using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class TempCustomerPaymentList
    {
        [Key]
        public int TempCPId { get; set; }

        public int PayeeId { get; set; }

        public int CustomerPaymentId { get; set; }

        public int SalesId { get; set; }

        public decimal? AmountDue { get; set; }

        public decimal? PaymentApplied { get; set; }

        public decimal? DiscountApplied { get; set; }

        public decimal? PaymentDiscount { get; set; }

        public decimal? ShortDiscount { get; set; }

        public decimal? OtherDiscount { get; set; }

        public bool IsApplied { get; set; }

        public int SalesNumber { get; set; }

        public DateOnly ShipDate { get; set; }

        public decimal? SalesTotal { get; set; }

        public string? ShipName { get; set; }

        public string? BillName { get; set; }

        public bool IsCCFee { get; set; }

        public decimal? LeaveShort
        {
            get
            {
                return IsApplied ? (AmountDue - PaymentApplied - DiscountApplied) : 0;
            }
        }

        [NotMapped]
        public bool IsPdfExist { get; set; }
    }
}
