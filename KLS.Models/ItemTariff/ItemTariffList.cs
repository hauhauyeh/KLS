using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class ItemTariffList
    {
        [Key]
        public int ItemTariffId { get; set; }

        public int ItemId { get; set; }

        public string? ItemCode { get; set; }

        public string? ItemName { get; set; }

        public string CountryCode { get; set; } = string.Empty;

        public string? CountryName { get; set; }

        public string? HSNCode { get; set; }

        [Column(TypeName = "decimal(9,6)")]
        public decimal? DutyRate { get; set; }

        [Column(TypeName = "decimal(9,4)")]
        public decimal? TariffRate { get; set; }

        public string? Notes { get; set; }

        public DateTime? UpdatedAt { get; set; }
    }
}
