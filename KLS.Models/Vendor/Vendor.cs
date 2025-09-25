using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class Vendor
    {
        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public int PayeeId { get; set; }

        public string LegalName { get; set; }

        public int BillingAddressId { get; set; }

        public string? AccountNumber { get; set; }

        public string? RoutingNumber { get; set; }

        public decimal? FreightRate { get; set; }

        public decimal? InterestRate { get; set; }

        public string? PaymentSchedule1 { get; set; }

        public string? PaymentSchedule2 { get; set; }

        public string? AccountCode1 { get; set; }

        public string? AccountCode2 { get; set; }

        public string? AccountCode3 { get; set; }

        public string? AccountCode4 { get; set; }

        public string? AccountCode5 { get; set; }

        public string? AccountCode6 { get; set; }

        public string? DefaultPaymentMethod { get; set; }

        public bool IsShippingCarrier { get; set; }

        public bool IsVisibleToAdmin { get; set; }
    }
}
