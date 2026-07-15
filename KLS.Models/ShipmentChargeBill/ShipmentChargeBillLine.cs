using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace KLS.Models
{
    public class ShipmentChargeBillLine
    {
        public ShipmentChargeBillLine()
        {
            CreatedAt = DateTime.UtcNow;
        }

        [Key]
        public int ShipmentChargeBillLineId { get; set; }

        [Required]
        public int ShipmentChargeBillId { get; set; }

        [Required]
        [MaxLength(50)]
        public string ChargeType { get; set; } = string.Empty;

        [Column(TypeName = "decimal(18,2)")]
        public decimal ChargeAmount { get; set; }

        [MaxLength(500)]
        public string? Notes { get; set; }

        public DateTime CreatedAt { get; set; }

        public DateTime? UpdatedAt { get; set; }
    }
}
