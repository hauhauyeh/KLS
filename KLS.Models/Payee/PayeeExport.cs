using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class PayeeExport
    {
        public string? Name { get; set; }

        [Key]
        public string? Company { get; set; }

        public string? CustomerType { get; set; }

        public string? Email { get; set; }

        public string? Phone { get; set; }

        public string? Mobile { get; set; }

        public string? Fax { get; set; }

        public string? Website { get; set; }

        public string? Street { get; set; }

        public string? City { get; set; }

        public string? State { get; set; }

        public string? ZipCode { get; set; }

        public string? Country { get; set; }

        public decimal? Balance { get; set; }

        public DateOnly? StartDate { get; set; }
    }
}
