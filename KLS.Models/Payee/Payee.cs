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

        /// <summary>
        /// Hidden system account (SYS1/SYS2). Excluded from every employee list,
        /// search and dropdown. Never set through the UI - see SystemAccounts_Seed.sql.
        /// </summary>
        public bool IsSystemAccount { get; set; }

        public string? GoogleAddress { get; set; }
        public string? GoogleMapLink { get; set; }
        public string? GooglePlaceId { get; set; }
        public string? GoogleLat { get; set; }
        public string? GoogleLong { get; set; }
        public string? FormatAddress { get; set; }
        public string? Distance { get; set; }
        public string? Website { get; set; }

        public string? Address { get; set; }
        public string? City { get; set; }
        public string? State { get; set; }
        public string? ZipCode { get; set; }
        public string? Country { get; set; }
        public string? AddressLine2 { get; set; }
        public string? CountryCode { get; set; }
        public string? Continent { get; set; }
        public string? Province { get; set; }
        public string? PostalCode { get; set; }
        public string? CurrencyCode { get; set; }
        public string? Locale { get; set; }
        public string? Timezone { get; set; }
        public string? TaxRegistrationNumber { get; set; }

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
        public DateOnly? StartDate { get; set; }
        public int? TermId { get; set; }
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

        public decimal? Invoice30 { get; set; }
        public decimal? Invoice60 { get; set; }
        public decimal? Invoice90 { get; set; }
        public decimal? InvoiceOver90 { get; set; }

        public decimal? Payee30Volume { get; set; }

        public DateOnly? LastOrderDate { get; set; }
        public decimal? LastOrderAmount { get; set; }
        public DateOnly? LastPaymentDate { get; set; }
        public decimal? LastPaymentAmount { get; set; }
        public int? AvgPaymentDays { get; set; }
        public DateOnly? FirstDueDate { get; set; }
        public int? MaxInvoiceAgingDays { get; set; }

        public DateTime CreatedAt { get; set; }
        public DateTime? UpdatedAt { get; set; }

        public virtual string FullAddress
        {
            get
            {
                return string.Join(", ", new[] { Address, City, State, ZipCode }
                .Where(x => !string.IsNullOrWhiteSpace(x)));
            }
        }
    }
}
