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

        // Per-bill redesign (Phase A): NULL = legacy shipment-wide charge (frozen/read-only);
        // NOT NULL = new per-vendor-bill charge (FK to ShipmentPurchase, charge-type basis rules enforced).
        public int? ShipmentPurchaseId { get; set; }

        public string? ChargeType { get; set; }

        public string? AllocationMethod { get; set; }

        // Per-bill redesign (Phase A). BillBasis = how a freight total lands on each bill (BY_PALLET/BY_SPACE_PCT;
        // freight-only). LineBasis = how a bill's charge spreads to its lines
        // (BY_VOLUME/BY_WEIGHT/BY_VALUE/BY_QUANTITY for freight, BY_DUTY_TARIFF for duty). NULL for legacy/manual.
        public string? BillBasis { get; set; }

        public string? LineBasis { get; set; }

        [Column(TypeName = "decimal(18,2)")]
        public decimal? ChargeAmount { get; set; }

        public string? Notes { get; set; }

        public bool IsGeneratedFromChargeBills { get; set; }

        public DateTime? UpdatedAt { get; set; }

        [NotMapped]
        public string? UsedMethod { get; set; }
    }
}
