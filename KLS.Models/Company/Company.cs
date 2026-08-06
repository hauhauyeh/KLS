using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Linq;
using System.Security.Principal;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class Company
    {
        public Company()
        {
            CreatedAt = DateTime.UtcNow;
            // LogoUrl is populated at report time (see CompanyService.GetDefault).
            // It must NOT be set here: EF calls this ctor before HasLogo is
            // materialized, so any HasLogo check here always sees false.
        }

        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public int CompanyId { get; set; }

        public string? CompanyCode { get; set; }

        public string? CompanyName { get; set; }

        public string? DisplayName { get; set; }

        public string? CompanyName2 { get; set; }

        public string? RegistrationNo { get; set; }

        public string? TaxId { get; set; }

        public string? BaseCurrency { get; set; }

        public string? TimeZone { get; set; }

        public DateOnly? FiscalYearStart { get; set; }

        public string? IndustryType { get; set; }

        public string? Email { get; set; }

        public string? Phone { get; set; }

        public string? SupportPhone { get; set; }

        public string? Website { get; set; }

        public string? SupportEmail { get; set; }

        public string? SalesEmail { get; set; }

        public string? AddressLine1 { get; set; }

        public string? AddressLine2 { get; set; }

        public string? City { get; set; }

        public string? State { get; set; }

        public string? ZipCode { get; set; }

        public string? CountryCode { get; set; }

        public string? BusinessHours { get; set; }

        public string? PublicAddressName { get; set; }

        public string? PublicContactName { get; set; }

        public string? WebLogoUrl { get; set; }

        public string? WebFaviconUrl { get; set; }

        public bool HasLogo { get; set; }

        public string? MapsLatLong { get; set; }

        public string? InvoiceFinePrint { get; set; }

        public string? InvoicePaymentTitle { get; set; }

        public string? InvoicePaymentBankName { get; set; }

        public string? InvoicePaymentAccountName { get; set; }

        public string? InvoicePaymentAccountNumber { get; set; }

        public string? InvoicePaymentRoutingNumber { get; set; }

        public string? InvoicePaymentAchRoutingNumber { get; set; }

        public string? InvoicePaymentZelleEmail { get; set; }

        public string? InvoicePaymentZellePhone { get; set; }

        public DateTime CreatedAt { get; set; }

        public DateTime? UpdatedAt { get; set; }

        [NotMapped]
        public string? LogoUrl { get; set; }

        [NotMapped]
        public string FullAddress
        {
            get
            {
                return string.Join(", ", new[] { AddressLine1, City, State, ZipCode, CountryCode }.Where(x => !string.IsNullOrWhiteSpace(x)));
            }
        }

        [NotMapped]
        public DateOnly NextWorkingDate { get; set; }
    }
}
