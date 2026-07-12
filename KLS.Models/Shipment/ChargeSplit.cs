using System;
using System.Collections.Generic;

namespace KLS.Models
{
    // Split-on-entry helper DTOs (Phase C). Endpoint: POST api/admin/Shipments/SplitCharge.
    // Creates/updates per-bill ShipmentCharge rows (ShipmentPurchaseId NOT NULL) for one shipment + charge type.
    // Freight is the primary path (split a carrier total across bills by pallet or space%); duty/tariff is
    // auto-derived per bill from line duty weights; manual/other is out of scope (deferred).

    public class ChargeSplitReq
    {
        public int ShipmentId { get; set; }

        // Freight | CustomDuty | Tariff (the per-bill charge types). Manual/other is rejected in Phase C.
        public string ChargeType { get; set; } = "";

        // Freight only: BY_PALLET | BY_SPACE_PCT. NULL for duty/tariff (no bill split).
        public string? BillBasis { get; set; }

        // Freight only: the carrier lump to split across the selected bills. Ignored for duty/tariff (auto-derived).
        public decimal CarrierTotal { get; set; }

        // Freight only: NULL = auto cascade per bill (VOLUME -> WEIGHT -> VALUE); or a user override (BY_QUANTITY).
        public string? ForcedLineBasis { get; set; }

        // The bills participating in this charge (selected member bills of the shipment).
        public List<ChargeSplitRow> Rows { get; set; } = new();
    }

    public class ChargeSplitRow
    {
        public int ShipmentPurchaseId { get; set; }

        // BY_PALLET input (share = PalletCount / SUM(PalletCount)).
        public decimal? PalletCount { get; set; }

        // BY_SPACE_PCT input (share = SpacePercent / 100; selected rows must sum to 100.00 +/- 0.01).
        public decimal? SpacePercent { get; set; }
    }

    public class ChargeSplitResponse
    {
        // The per-bill charges written (preview == saved once applied).
        public List<ChargeSplitResultRow> Rows { get; set; } = new();

        // Actionable validation / info messages surfaced to the user.
        public List<string> Messages { get; set; } = new();

        // Parent should reload the shipment's charges/allocation state after a successful save.
        public bool Reload { get; set; }
    }

    public class ChargeSplitResultRow
    {
        public int ShipmentPurchaseId { get; set; }
        public int ChargeId { get; set; }
        public string ChargeType { get; set; } = "";

        // Per-bill charge amount (freight share, or auto-derived duty total for the bill).
        public decimal ChargeAmount { get; set; }

        // BY_PALLET / BY_SPACE_PCT (freight) or NULL (duty).
        public string? BillBasis { get; set; }

        // Resolved per-bill LineBasis stored on the charge (BY_VOLUME/.../BY_DUTY_TARIFF).
        public string? LineBasis { get; set; }
    }
}
