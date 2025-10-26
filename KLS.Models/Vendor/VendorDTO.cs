using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class VendorDTO
    {
        [Key]
        public int PayeeId { get; set; }

        public string? PayeeName { get; set; }

        public string? Address { get; set; }

        public string? City { get; set; }

        public string? State { get; set; }

        public string? ZipCode { get; set; }

        public string? Country { get; set; }

        public string? PhoneDesc1 { get; set; }

        public string? Phone1 { get; set; }

        public string? PhoneDesc2 { get; set; }

        public string? Phone2 { get; set; }

        public string? PhoneDesc3 { get; set; }

        public string? Phone3 { get; set; }

        public string? PhoneDesc4 { get; set; }

        public string? Phone4 { get; set; }

        public string? PhoneDesc5 { get; set; }

        public string? Phone5 { get; set; }

        public string? PhoneDesc6 { get; set; }

        public string? Phone6 { get; set; }

        public string? Email { get; set; }

        public decimal? Balance { get; set; }

        public string? Notes { get; set; }

        public bool IsClosed { get; set; }

        public int? TermId { get; set; }

        public DateTime? StartDate { get; set; }

        public string? GoogleAddress { get; set; }

        //public string PmtCompany { get; set; }

        //public string? PmtAddress { get; set; }

        //public string? PmtCity { get; set; }

        //public string? PmtState { get; set; }

        //public string? PmtZipCode { get; set; }

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
