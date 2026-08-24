using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;

namespace KLS.Models
{
    public class ShipmentChargeBill
    {
        public ShipmentChargeBill()
        {
            CreatedAt = DateTime.UtcNow;
        }

        [Key]
        public int ShipmentChargeBillId { get; set; }

        [Required]
        public int ShipmentId { get; set; }

        [Required]
        public int VendorPayeeId { get; set; }

        [MaxLength(100)]
        public string? VendorDocNumber { get; set; }

        public DateOnly? BillDate { get; set; }

        public int? PurchaseId { get; set; }

        public int? SourceSharedShipmentChargeBillSplitId { get; set; }

        [MaxLength(500)]
        public string? Notes { get; set; }

        public DateTime CreatedAt { get; set; }

        public DateTime? UpdatedAt { get; set; }

        public virtual ICollection<ShipmentChargeBillLine>? Lines { get; set; }
    }
}
