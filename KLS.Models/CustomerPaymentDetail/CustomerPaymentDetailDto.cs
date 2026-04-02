using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class CustomerPaymentDetailDto
    {
        [Key]
        public int PaymentDetailId { get; set; }

        public int CustomerPaymentId { get; set; }

        public int SalesId { get; set; }

        public decimal? PaymentApplied { get; set; }

        public decimal? DiscountApplied { get; }

        public decimal? PaymentDiscount { get; set; }

        public decimal? ShortDiscount { get; set; }

        public decimal? OtherDiscount { get; set; }

        public int SalesNumber { get; set; }
    }
}
