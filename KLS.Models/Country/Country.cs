using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Reflection.Metadata.Ecma335;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class Country
    {
        [Key]
        public int CountryId { get; set; }

        public string CountryCode { get; set; } = string.Empty;

        public string CountryName { get; set; } = string.Empty;

        public string ISOAlpha2 { get; set; } = string.Empty;

        public string ISOAlpha3 { get; set; } = string.Empty;

        public string? NumericCode { get; set; }

        public string? CallingCode { get; set; }

        public string? Continent { get; set; }

        public bool IsActive { get; set; }

        public int? SortOrder { get; set; }

        public DateTime CreatedAt { get; set; }

        public DateTime? UpdatedAt { get; set; }
    }
}
