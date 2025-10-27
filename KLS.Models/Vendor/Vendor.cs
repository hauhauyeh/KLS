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

        public string CompanyName { get; set; }

        public string? PaymentAddress { get; set; }

        public string? PaymentCity { get; set; }

        public string? PaymentState { get; set; }

        public string? PaymentZipCode { get; set; }

        public string? AccountNumber { get; set; }

        public string? RoutingNumber { get; set; }

        public decimal? FreightRate { get; set; }

        public decimal? InterestRate { get; set; }

        public int? AccountId1 { get; set; }

        public int? AccountId2 { get; set; }

        public int? AccountId3 { get; set; }

        public int? AccountId4 { get; set; }

        public int? AccountId5 { get; set; }

        public int? AccountId6 { get; set; }

        public string? DefaultPaymentMethod { get; set; }

        public bool IsShippingCarrier { get; set; }

        public bool IsVisibleToAdmin { get; set; }
    }
}
