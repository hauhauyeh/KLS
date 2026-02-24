using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class ItemTariff
    {
        public ItemTariff()
        {
            this.CreatedAt = DateTime.UtcNow;
        }

        [Key]
        public int ItemTariffId { get; set; }

        [Required]
        public int ItemId { get; set; }

        [Required]
        [StringLength(3)]
        public string CountryCode { get; set; } = string.Empty;

        [Column(TypeName = "decimal(9,6)")]
        public decimal? DutyRate { get; set; }

        [Column(TypeName = "decimal(9,4)")]
        public decimal? TariffRate { get; set; }

        public DateTime? CreatedAt { get; set; }

        public DateTime? UpdatedAt { get; set; }
    }
}
