using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Linq;
using System.Numerics;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class Payee
    {
        public Payee()
        {
            this.CreatedAt = DateTime.UtcNow;
        }

        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public int Id { get; set; }

        [Key]
        public int PayeeId { get; set; }

        public string? PayeeType { get; set; }

        public string? PayeeName { get; set; }
        public string? GoogleAddress { get; set; }
        public string? GoogleMapLink { get; set; }
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
        public string? EmailInvoice { get; set; }
        public string? EmailStmt { get; set; }
        public string? EmailPricesheet { get; set; }
        public string? EmailACH { get; set; }

        public bool IsClosed { get; set; }
        public DateTime? StartDate { get; set; }
        public string? TermName { get; set; }
        public int? GracePeriod { get; set; }

        public bool IsPastDue { get; set; }
        public bool IsCreditHold { get; set; }
        public bool IsDelinquent { get; set; }

        public decimal? Balance { get; set; }
        public string? Notes { get; set; }

        public decimal? PayeeCurrent { get; set; }
        public decimal? Payee30 { get; set; }
        public decimal? Payee60 { get; set; }
        public decimal? Payee90 { get; set; }
        public decimal? PayeeOver90 { get; set; }
        public decimal? PayeeTotalDue { get; set; }
        public decimal? PayeePastDue { get; set; }

        public decimal? Inv30 { get; set; }
        public decimal? Inv60 { get; set; }
        public decimal? Inv90 { get; set; }
        public decimal? InvOver90 { get; set; }

        public decimal? Payee30Volume { get; set; }

        public DateTime? CreatedAt { get; set; }
        public DateTime? UpdatedAt { get; set; }


        public Employee? Employee { get; set; }

        public Customer? Customer { get; set; }

        public Vendor? Vendor { get; set; }

        public SystemUser? User { get; set; }
    }
}
