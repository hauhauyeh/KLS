using System;
using System.ComponentModel.DataAnnotations;

namespace KLS.Models
{
    public class SharedShipmentChargeBillSplit
    {
        public SharedShipmentChargeBillSplit()
        {
            CreatedAt = DateTime.UtcNow;
        }

        [Key]
        public int SharedShipmentChargeBillSplitId { get; set; }

        public int SharedShipmentChargeBillId { get; set; }

        public int ShipmentId { get; set; }

        [MaxLength(30)]
        public string SplitMethod { get; set; } = string.Empty;

        public decimal? SplitPercent { get; set; }

        public decimal SplitAmount { get; set; }

        [MaxLength(100)]
        public string? GeneratedVendorDocNumber { get; set; }

        [MaxLength(500)]
        public string? Notes { get; set; }

        public DateTime CreatedAt { get; set; }

        public DateTime? UpdatedAt { get; set; }
    }
}
