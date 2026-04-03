using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class ShipmentCharge
    {
        [Key]
        public int ChargeId { get; set; }

        public int ShipmentId { get; set; }

        public string? ChargeType { get; set; }

        public string? AllocationMethod { get; set; }

        [Column(TypeName = "decimal(18,2)")]
        public decimal? ChargeAmount { get; set; }

        public string? Notes { get; set; }

        public DateTime? UpdatedAt { get; set; }

        [NotMapped]
        public string? UsedMethod { get; set; }
    }
}
