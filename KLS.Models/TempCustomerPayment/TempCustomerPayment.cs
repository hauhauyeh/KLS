using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class TempCustomerPayment
    {
        [Key]
        public int TempCPId { get; set; }

        public int EmpId { get; set; }

        public int PayeeId { get; set; }

        public int CustomerPaymentId { get; set; }

        public int SalesId { get; set; }

        public decimal? AmountDue { get; set; }

        public decimal? PaymentApplied { get; set; }

        public decimal? DiscountApplied { get; }

        public decimal? PaymentDiscount { get; set; }

        public decimal? ShortDiscount { get; set; }

        public decimal? OtherDiscount { get; set; }

        public bool IsApplied { get; set; }
    }
}
