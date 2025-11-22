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
            this.CreatedAt = DateTime.UtcNow;
        }

        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public int CompanyId { get; set; }

        public string? CompanyCode { get; set; }

        public string? CompanyName { get; set; }

        public string? DisplayName { get; set; }

        public string? RegistrationNo { get; set; }

        public string? TaxId { get; set; }

        public decimal? BaseCurrency { get; set; }

        public string? TimeZone { get; set; }

        public DateOnly? FiscalYearStart { get; set; }

        public string? IndustryType { get; set; }

        public string? Email { get; set; }

        public string? Phone { get; set; }

        public string? Website { get; set; }

        public string? AddressLine1 { get; set; }

        public string? AddressLine2 { get; set; }

        public string? City { get; set; }

        public string? State { get; set; }

        public string? ZipCode { get; set; }

        public string? CountryCode { get; set; }

        public bool HasLogo { get; set; }

        public DateTime? CreatedAt { get; set; }

        public DateTime? UpdatedAt { get; set; }
    }
}
