using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;

namespace KLS.Models
{
    public class SharedShipmentChargeBill
    {
        public SharedShipmentChargeBill()
        {
            CreatedAt = DateTime.UtcNow;
            Status = "Draft";
        }

        [Key]
        public int SharedShipmentChargeBillId { get; set; }

        public int VendorPayeeId { get; set; }

        [MaxLength(100)]
        public string? VendorDocNumber { get; set; }

        public DateOnly? BillDate { get; set; }

        [MaxLength(20)]
        public string Status { get; set; }

        [MaxLength(500)]
        public string? Notes { get; set; }

        public DateTime CreatedAt { get; set; }

        public DateTime? UpdatedAt { get; set; }

        public virtual ICollection<SharedShipmentChargeBillLine>? Lines { get; set; }

        public virtual ICollection<SharedShipmentChargeBillSplit>? Splits { get; set; }
    }
}
