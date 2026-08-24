using System;
using System.ComponentModel.DataAnnotations;

namespace KLS.Models
{
    // Keyless result for Shipment_EligibleBills - the bills selectable in the Multi-Bill Assign
    // picker. Eligible = bill stage (StageId=6), not a shipment bill, not already assigned to any
    // shipment, and not locked/paid. Queried only via FromSqlRaw; PurchaseId is unique so it
    // serves as the EF key (no backing table).
    public class EligibleBill
    {
        [Key]
        public int PurchaseId { get; set; }

        public int PurchaseNumber { get; set; }

        public int? StageId { get; set; }

        public int PayeeId { get; set; }

        public string? PayeeName { get; set; }

        public DateOnly? ArrivalDate { get; set; }

        public string? VendorDocNumber { get; set; }

        public string? ContainerNumber { get; set; }

        public decimal? PurchaseTotal { get; set; }

        public bool IsLocked { get; set; }

        // 2026-07-13 (Slice B): reference-only shipment link; no landed cost.
        public bool IsDropShip { get; set; }

        public bool IsContainerMatch { get; set; }

        public int ContainerMatchRank { get; set; }
    }
}
