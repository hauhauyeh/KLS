using System;
using System.ComponentModel.DataAnnotations;

namespace KLS.Models
{
    public class SharedShipmentChargeBillLine
    {
        public SharedShipmentChargeBillLine()
        {
            CreatedAt = DateTime.UtcNow;
        }

        [Key]
        public int SharedShipmentChargeBillLineId { get; set; }

        public int SharedShipmentChargeBillId { get; set; }

        [MaxLength(50)]
        public string ChargeType { get; set; } = string.Empty;

        public decimal ChargeAmount { get; set; }

        [MaxLength(500)]
        public string? Notes { get; set; }

        public DateTime CreatedAt { get; set; }

        public DateTime? UpdatedAt { get; set; }
    }
}
